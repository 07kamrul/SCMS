import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/progress_report_repository.dart';
import 'progress_reports_list_event.dart';
import 'progress_reports_list_state.dart';

/// Loads and paginates [ProgressReport]s for a single project.
class ProgressReportsListBloc extends Bloc<ProgressReportsListEvent, ProgressReportsListState> {
  ProgressReportsListBloc(this._repository) : super(const ProgressReportsListInitial()) {
    on<ProgressReportsListStarted>(_onStarted);
    on<ProgressReportsListMoreRequested>(_onMoreRequested);
  }

  final ProgressReportRepository _repository;

  static const _pageSize = 20;

  String? _projectId;
  int _loadedPage = 1;

  Future<void> _onStarted(
    ProgressReportsListStarted event,
    Emitter<ProgressReportsListState> emit,
  ) async {
    _projectId = event.projectId;
    _loadedPage = 1;
    emit(const ProgressReportsListLoading());
    try {
      final result = await _repository.list(
        projectId: _projectId,
        page: _loadedPage,
        pageSize: _pageSize,
      );
      emit(
        ProgressReportsListLoaded(
          reports: result.reports,
          hasMore: result.reports.length < result.total,
        ),
      );
    } on ApiException catch (e) {
      emit(ProgressReportsListFailure(e.message));
    }
  }

  Future<void> _onMoreRequested(
    ProgressReportsListMoreRequested event,
    Emitter<ProgressReportsListState> emit,
  ) async {
    final current = state;
    if (current is! ProgressReportsListLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true, loadMoreError: null));
    try {
      final nextPage = _loadedPage + 1;
      final result = await _repository.list(
        projectId: _projectId,
        page: nextPage,
        pageSize: _pageSize,
      );
      _loadedPage = nextPage;
      final combined = [...current.reports, ...result.reports];
      emit(
        ProgressReportsListLoaded(
          reports: combined,
          hasMore: combined.length < result.total,
        ),
      );
    } on ApiException catch (e) {
      emit(current.copyWith(isLoadingMore: false, loadMoreError: e.message));
    }
  }
}
