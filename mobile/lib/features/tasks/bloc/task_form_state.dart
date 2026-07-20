import 'package:equatable/equatable.dart';

import '../data/task_models.dart';
import 'task_form_event.dart' show AssignableUser;

/// Sentinel used by [TaskFormState.copyWith] so nullable fields can be
/// explicitly cleared (e.g. unassigning, clearing the due date).
const Object _unset = Object();

/// State for the create-task form.
class TaskFormState extends Equatable {
  const TaskFormState({
    this.projectId = '',
    this.assignableUsers = const [],
    this.title = '',
    this.description = '',
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.assignedToUserId,
    this.isSubmitting = false,
    this.isSuccess = false,
    this.isOfflineQueued = false,
    this.errorMessage,
    this.createdTask,
  });

  final String projectId;
  final List<AssignableUser> assignableUsers;
  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? assignedToUserId;
  final bool isSubmitting;
  final bool isSuccess;

  /// Set instead of [isSuccess] when submission fails with a *network* error
  /// — the task has been queued via `OfflineQueueRepository.enqueueSubmission`
  /// (`kind: 'task_status'`) and `SubmissionRetryService` will create it for
  /// real once connectivity returns. The UI should treat this like success
  /// (close the form) but say "saved offline, will sync" instead.
  final bool isOfflineQueued;
  final String? errorMessage;
  final Task? createdTask;

  bool get isValid => title.trim().isNotEmpty && title.trim().length <= 200;

  TaskFormState copyWith({
    String? projectId,
    List<AssignableUser>? assignableUsers,
    String? title,
    String? description,
    TaskPriority? priority,
    Object? dueDate = _unset,
    Object? assignedToUserId = _unset,
    bool? isSubmitting,
    bool? isSuccess,
    bool? isOfflineQueued,
    Object? errorMessage = _unset,
    Task? createdTask,
  }) {
    return TaskFormState(
      projectId: projectId ?? this.projectId,
      assignableUsers: assignableUsers ?? this.assignableUsers,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      assignedToUserId: identical(assignedToUserId, _unset)
          ? this.assignedToUserId
          : assignedToUserId as String?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      createdTask: createdTask ?? this.createdTask,
    );
  }

  @override
  List<Object?> get props => [
    projectId,
    assignableUsers,
    title,
    description,
    priority,
    dueDate,
    assignedToUserId,
    isSubmitting,
    isSuccess,
    isOfflineQueued,
    errorMessage,
    createdTask,
  ];
}
