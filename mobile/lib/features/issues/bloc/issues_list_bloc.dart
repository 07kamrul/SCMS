import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/issue_repository.dart';
import 'issues_list_event.dart';
import 'issues_list_state.dart';

const _pageSize = 20;

/// Loads, paginates, and filters the issues list for a project (or across
/// all visible projects when `projectId` is null).
class IssuesListBloc extends Bloc<IssuesListEvent, IssuesListState> {
  IssuesListBloc(this._issueRepository) : super(const IssuesListState()) {
    on<IssuesListStarted>(_onStarted);
    on<IssuesListRefreshed>(_onRefreshed);
    on<IssuesListNextPageRequested>(_onNextPageRequested);
    on<IssuesListFilterChanged>(_onFilterChanged);
  }

  final IssueRepository _issueRepository;

  Future<void> _onStarted(
    IssuesListStarted event,
    Emitter<IssuesListState> emit,
  ) async {
    emit(
      IssuesListState(
        status: IssuesListStatus.loading,
        projectId: event.projectId,
      ),
    );
    await _loadPage(1, emit, replace: true);
  }

  Future<void> _onRefreshed(
    IssuesListRefreshed event,
    Emitter<IssuesListState> emit,
  ) async {
    await _loadPage(1, emit, replace: true);
  }

  Future<void> _onNextPageRequested(
    IssuesListNextPageRequested event,
    Emitter<IssuesListState> emit,
  ) async {
    if (state.hasReachedMax || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    await _loadPage(state.page + 1, emit, replace: false);
  }

  Future<void> _onFilterChanged(
    IssuesListFilterChanged event,
    Emitter<IssuesListState> emit,
  ) async {
    emit(
      state.copyWith(
        status: IssuesListStatus.loading,
        statusFilter: event.status,
        clearStatusFilter: event.status == null,
        priorityFilter: event.priority,
        clearPriorityFilter: event.priority == null,
        categoryFilter: event.category,
        clearCategoryFilter: event.category == null,
      ),
    );
    await _loadPage(1, emit, replace: true);
  }

  Future<void> _loadPage(
    int page,
    Emitter<IssuesListState> emit, {
    required bool replace,
  }) async {
    try {
      final result = await _issueRepository.list(
        projectId: state.projectId,
        status: state.statusFilter,
        priority: state.priorityFilter,
        category: state.categoryFilter,
        page: page,
        pageSize: _pageSize,
      );
      final items = replace ? result.items : [...state.issues, ...result.items];
      emit(
        state.copyWith(
          status: IssuesListStatus.success,
          issues: items,
          page: page,
          hasReachedMax: page >= result.meta.totalPages,
          isLoadingMore: false,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: IssuesListStatus.failure,
          isLoadingMore: false,
          errorMessage: e.message,
        ),
      );
    }
  }
}
