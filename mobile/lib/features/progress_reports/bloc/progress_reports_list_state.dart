import 'package:equatable/equatable.dart';

import '../data/progress_report_models.dart';

/// States emitted by [ProgressReportsListBloc].
sealed class ProgressReportsListState extends Equatable {
  const ProgressReportsListState();

  @override
  List<Object?> get props => [];
}

/// Before the first load has run.
final class ProgressReportsListInitial extends ProgressReportsListState {
  const ProgressReportsListInitial();
}

/// The first page is loading (no data on screen yet).
final class ProgressReportsListLoading extends ProgressReportsListState {
  const ProgressReportsListLoading();
}

/// [reports] loaded so far, across however many pages. [hasMore] indicates
/// whether additional pages exist. [isLoadingMore] is true while a
/// next-page request is in flight. [loadMoreError] is set (transiently)
/// when a next-page request fails — the already-loaded [reports] are kept
/// on screen rather than discarded.
final class ProgressReportsListLoaded extends ProgressReportsListState {
  const ProgressReportsListLoaded({
    required this.reports,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<ProgressReport> reports;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;

  ProgressReportsListLoaded copyWith({
    List<ProgressReport>? reports,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
  }) {
    return ProgressReportsListLoaded(
      reports: reports ?? this.reports,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError,
    );
  }

  @override
  List<Object?> get props => [reports, hasMore, isLoadingMore, loadMoreError];
}

/// The initial (page-1) load failed.
final class ProgressReportsListFailure extends ProgressReportsListState {
  const ProgressReportsListFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
