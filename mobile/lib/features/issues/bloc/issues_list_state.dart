import 'package:equatable/equatable.dart';

import '../data/issue_models.dart';

enum IssuesListStatus { initial, loading, success, failure }

/// State for [IssuesListBloc]. A single class (rather than a sealed
/// hierarchy) so pagination/filter metadata survives across loading and
/// success emissions without being re-threaded through every subtype.
class IssuesListState extends Equatable {
  const IssuesListState({
    this.status = IssuesListStatus.initial,
    this.issues = const [],
    this.page = 1,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.projectId,
    this.statusFilter,
    this.priorityFilter,
    this.categoryFilter,
    this.errorMessage,
  });

  final IssuesListStatus status;
  final List<Issue> issues;
  final int page;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? projectId;
  final IssueStatus? statusFilter;
  final IssuePriority? priorityFilter;
  final IssueCategory? categoryFilter;
  final String? errorMessage;

  IssuesListState copyWith({
    IssuesListStatus? status,
    List<Issue>? issues,
    int? page,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? projectId,
    IssueStatus? statusFilter,
    bool clearStatusFilter = false,
    IssuePriority? priorityFilter,
    bool clearPriorityFilter = false,
    IssueCategory? categoryFilter,
    bool clearCategoryFilter = false,
    String? errorMessage,
  }) {
    return IssuesListState(
      status: status ?? this.status,
      issues: issues ?? this.issues,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      projectId: projectId ?? this.projectId,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      priorityFilter: clearPriorityFilter ? null : (priorityFilter ?? this.priorityFilter),
      categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    issues,
    page,
    hasReachedMax,
    isLoadingMore,
    projectId,
    statusFilter,
    priorityFilter,
    categoryFilter,
    errorMessage,
  ];
}
