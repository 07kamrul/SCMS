import 'package:equatable/equatable.dart';

import '../data/task_models.dart';

/// Events consumed by [TasksListBloc].
sealed class TasksListEvent extends Equatable {
  const TasksListEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the list page is first shown. Resets any previous
/// filters/pagination and loads page 1 for [projectId] (or all projects
/// visible to the current user if `null`).
final class TasksListSubscriptionRequested extends TasksListEvent {
  const TasksListSubscriptionRequested({this.projectId});

  final String? projectId;

  @override
  List<Object?> get props => [projectId];
}

/// Pull-to-refresh: reloads page 1 with the current filters.
final class TasksListRefreshed extends TasksListEvent {
  const TasksListRefreshed();
}

/// Infinite-scroll: loads the next page and appends it to the current list.
final class TasksListNextPageRequested extends TasksListEvent {
  const TasksListNextPageRequested();
}

/// Changes the status filter chip (`null` clears the filter) and reloads
/// from page 1.
final class TasksListStatusFilterChanged extends TasksListEvent {
  const TasksListStatusFilterChanged(this.status);

  final TaskStatus? status;

  @override
  List<Object?> get props => [status];
}

/// Changes the priority filter chip (`null` clears the filter) and reloads
/// from page 1.
final class TasksListPriorityFilterChanged extends TasksListEvent {
  const TasksListPriorityFilterChanged(this.priority);

  final TaskPriority? priority;

  @override
  List<Object?> get props => [priority];
}

/// Toggles the "overdue only" chip and reloads from page 1.
final class TasksListOverdueFilterToggled extends TasksListEvent {
  const TasksListOverdueFilterToggled(this.overdueOnly);

  final bool overdueOnly;

  @override
  List<Object?> get props => [overdueOnly];
}
