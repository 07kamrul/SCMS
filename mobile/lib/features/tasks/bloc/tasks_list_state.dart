import 'package:equatable/equatable.dart';

import '../data/task_models.dart';

/// Sentinel used by [TasksListState.copyWith] so a filter can be explicitly
/// cleared (set to `null`) as opposed to left unchanged.
const Object _unset = Object();

/// Single state for the task list page: current page of [tasks], active
/// filters, and pagination/loading flags.
class TasksListState extends Equatable {
  const TasksListState({
    this.projectId,
    this.statusFilter,
    this.priorityFilter,
    this.overdueOnly = false,
    this.tasks = const [],
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final String? projectId;
  final TaskStatus? statusFilter;
  final TaskPriority? priorityFilter;
  final bool overdueOnly;
  final List<Task> tasks;
  final int page;
  final int pageSize;
  final int total;

  /// True while loading page 1 (initial load, refresh, or filter change).
  final bool isLoading;

  /// True while appending a subsequent page.
  final bool isLoadingMore;

  final String? errorMessage;

  bool get hasMore => tasks.length < total;

  TasksListState copyWith({
    Object? projectId = _unset,
    Object? statusFilter = _unset,
    Object? priorityFilter = _unset,
    bool? overdueOnly,
    List<Task>? tasks,
    int? page,
    int? pageSize,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    Object? errorMessage = _unset,
  }) {
    return TasksListState(
      projectId: identical(projectId, _unset)
          ? this.projectId
          : projectId as String?,
      statusFilter: identical(statusFilter, _unset)
          ? this.statusFilter
          : statusFilter as TaskStatus?,
      priorityFilter: identical(priorityFilter, _unset)
          ? this.priorityFilter
          : priorityFilter as TaskPriority?,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      tasks: tasks ?? this.tasks,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    projectId,
    statusFilter,
    priorityFilter,
    overdueOnly,
    tasks,
    page,
    pageSize,
    total,
    isLoading,
    isLoadingMore,
    errorMessage,
  ];
}
