import 'package:equatable/equatable.dart';

import '../data/task_models.dart';

/// Sentinel used by [TaskDetailState.copyWith] so nullable fields (e.g. the
/// transient action error) can be explicitly cleared.
const Object _unset = Object();

/// Combined state for the task detail page: the task itself plus its
/// comments and photos, loaded together since the page displays everything
/// at once.
class TaskDetailState extends Equatable {
  const TaskDetailState({
    this.task,
    this.comments = const [],
    this.photos = const [],
    this.isLoading = false,
    this.isUpdatingTask = false,
    this.isSubmittingComment = false,
    this.isAddingPhoto = false,
    this.errorMessage,
    this.actionErrorMessage,
  });

  final Task? task;
  final List<TaskComment> comments;
  final List<TaskPhoto> photos;

  /// True while the initial load (or a full refresh) is in flight.
  final bool isLoading;

  /// True while a status/priority/assignee change is in flight.
  final bool isUpdatingTask;

  /// True while a comment submission is in flight.
  final bool isSubmittingComment;

  /// True while a newly-uploaded photo is being persisted.
  final bool isAddingPhoto;

  /// Set when the initial load fails.
  final String? errorMessage;

  /// Transient error from a status/priority/assignee/comment/photo action
  /// (e.g. a permission-denied response) — the UI should surface this once
  /// (a `SnackBar`/listener) rather than treat it as a persistent state.
  final String? actionErrorMessage;

  TaskDetailState copyWith({
    Task? task,
    List<TaskComment>? comments,
    List<TaskPhoto>? photos,
    bool? isLoading,
    bool? isUpdatingTask,
    bool? isSubmittingComment,
    bool? isAddingPhoto,
    Object? errorMessage = _unset,
    Object? actionErrorMessage = _unset,
  }) {
    return TaskDetailState(
      task: task ?? this.task,
      comments: comments ?? this.comments,
      photos: photos ?? this.photos,
      isLoading: isLoading ?? this.isLoading,
      isUpdatingTask: isUpdatingTask ?? this.isUpdatingTask,
      isSubmittingComment: isSubmittingComment ?? this.isSubmittingComment,
      isAddingPhoto: isAddingPhoto ?? this.isAddingPhoto,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      actionErrorMessage: identical(actionErrorMessage, _unset)
          ? this.actionErrorMessage
          : actionErrorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    task,
    comments,
    photos,
    isLoading,
    isUpdatingTask,
    isSubmittingComment,
    isAddingPhoto,
    errorMessage,
    actionErrorMessage,
  ];
}
