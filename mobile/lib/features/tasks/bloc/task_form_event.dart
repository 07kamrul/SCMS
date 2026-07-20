import 'package:equatable/equatable.dart';

import '../data/task_models.dart';

/// A user assignable to a task, as supplied by the caller (typically the
/// `team` feature). Kept as a bare record here so this bloc stays decoupled
/// from any other feature's models.
typedef AssignableUser = ({String id, String name});

/// Events consumed by [TaskFormBloc].
sealed class TaskFormEvent extends Equatable {
  const TaskFormEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the create-task form opens.
final class TaskFormInitialized extends TaskFormEvent {
  const TaskFormInitialized({
    required this.projectId,
    this.assignableUsers = const [],
  });

  final String projectId;
  final List<AssignableUser> assignableUsers;

  @override
  List<Object?> get props => [projectId, assignableUsers];
}

final class TaskFormTitleChanged extends TaskFormEvent {
  const TaskFormTitleChanged(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

final class TaskFormDescriptionChanged extends TaskFormEvent {
  const TaskFormDescriptionChanged(this.description);

  final String description;

  @override
  List<Object?> get props => [description];
}

final class TaskFormPriorityChanged extends TaskFormEvent {
  const TaskFormPriorityChanged(this.priority);

  final TaskPriority priority;

  @override
  List<Object?> get props => [priority];
}

final class TaskFormDueDateChanged extends TaskFormEvent {
  const TaskFormDueDateChanged(this.dueDate);

  final DateTime? dueDate;

  @override
  List<Object?> get props => [dueDate];
}

final class TaskFormAssigneeChanged extends TaskFormEvent {
  const TaskFormAssigneeChanged(this.assignedToUserId);

  final String? assignedToUserId;

  @override
  List<Object?> get props => [assignedToUserId];
}

final class TaskFormSubmitted extends TaskFormEvent {
  const TaskFormSubmitted();
}
