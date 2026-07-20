import 'package:equatable/equatable.dart';

import '../data/task_models.dart';

/// Events consumed by [TaskDetailBloc].
sealed class TaskDetailEvent extends Equatable {
  const TaskDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the detail page opens: loads the task, its comments,
/// and its photos together.
final class TaskDetailLoadRequested extends TaskDetailEvent {
  const TaskDetailLoadRequested(this.taskId);

  final String taskId;

  @override
  List<Object?> get props => [taskId];
}

/// Reloads the task, comments, and photos for the already-loaded task.
final class TaskDetailRefreshRequested extends TaskDetailEvent {
  const TaskDetailRefreshRequested();
}

/// Changes the task status (e.g. via a dropdown). The caller is responsible
/// for only offering statuses the current user is allowed to set — the
/// backend still enforces this and a rejection surfaces as
/// [TaskDetailState.actionErrorMessage].
final class TaskDetailStatusChanged extends TaskDetailEvent {
  const TaskDetailStatusChanged(this.status);

  final TaskStatus status;

  @override
  List<Object?> get props => [status];
}

/// Changes the task priority.
final class TaskDetailPriorityChanged extends TaskDetailEvent {
  const TaskDetailPriorityChanged(this.priority);

  final TaskPriority priority;

  @override
  List<Object?> get props => [priority];
}

/// Reassigns the task to a different user (or unassigns when `null`).
final class TaskDetailAssigneeChanged extends TaskDetailEvent {
  const TaskDetailAssigneeChanged(this.assignedToUserId);

  final String? assignedToUserId;

  @override
  List<Object?> get props => [assignedToUserId];
}

/// Submits a new comment.
final class TaskDetailCommentAdded extends TaskDetailEvent {
  const TaskDetailCommentAdded(this.body);

  final String body;

  @override
  List<Object?> get props => [body];
}

/// Fired once [PhotoPickerField] has already completed the full
/// presign+PUT+attach call for a new photo (`POST /tasks/{id}/photos`) — this
/// just appends the already-server-confirmed [photo] to the visible grid; no
/// further network call is made here.
final class TaskDetailPhotoAttached extends TaskDetailEvent {
  const TaskDetailPhotoAttached(this.photo);

  final TaskPhoto photo;

  @override
  List<Object?> get props => [photo];
}
