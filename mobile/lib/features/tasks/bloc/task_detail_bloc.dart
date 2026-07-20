import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/task_repository.dart';
import 'task_detail_event.dart';
import 'task_detail_state.dart';

/// Loads a single task together with its comments and photos, and handles
/// every mutation the detail page can trigger (status/priority/assignee
/// changes, adding a comment, recording an uploaded photo).
class TaskDetailBloc extends Bloc<TaskDetailEvent, TaskDetailState> {
  TaskDetailBloc(this._taskRepository) : super(const TaskDetailState()) {
    on<TaskDetailLoadRequested>(_onLoadRequested);
    on<TaskDetailRefreshRequested>(_onRefreshRequested);
    on<TaskDetailStatusChanged>(_onStatusChanged);
    on<TaskDetailPriorityChanged>(_onPriorityChanged);
    on<TaskDetailAssigneeChanged>(_onAssigneeChanged);
    on<TaskDetailCommentAdded>(_onCommentAdded);
    on<TaskDetailPhotoAttached>(_onPhotoAttached);
  }

  final TaskRepository _taskRepository;

  /// Set on the first successful load so later events (refresh, mutations)
  /// don't need the id passed again.
  String? _taskId;

  Future<void> _onLoadRequested(
    TaskDetailLoadRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    _taskId = event.taskId;
    emit(const TaskDetailState(isLoading: true));
    await _loadAll(emit);
  }

  Future<void> _onRefreshRequested(
    TaskDetailRefreshRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _loadAll(emit);
  }

  Future<void> _loadAll(Emitter<TaskDetailState> emit) async {
    final taskId = _taskId;
    if (taskId == null) return;
    try {
      final task = await _taskRepository.getById(taskId);
      final comments = await _taskRepository.listComments(taskId);
      final photos = await _taskRepository.listPhotos(taskId);
      emit(
        state.copyWith(
          task: task,
          comments: comments,
          photos: photos,
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    }
  }

  Future<void> _onStatusChanged(
    TaskDetailStatusChanged event,
    Emitter<TaskDetailState> emit,
  ) async {
    final taskId = _taskId;
    if (taskId == null) return;
    emit(state.copyWith(isUpdatingTask: true, actionErrorMessage: null));
    try {
      final task = await _taskRepository.update(taskId, status: event.status);
      emit(state.copyWith(task: task, isUpdatingTask: false));
    } on ApiException catch (e) {
      emit(
        state.copyWith(isUpdatingTask: false, actionErrorMessage: e.message),
      );
    }
  }

  Future<void> _onPriorityChanged(
    TaskDetailPriorityChanged event,
    Emitter<TaskDetailState> emit,
  ) async {
    final taskId = _taskId;
    if (taskId == null) return;
    emit(state.copyWith(isUpdatingTask: true, actionErrorMessage: null));
    try {
      final task = await _taskRepository.update(
        taskId,
        priority: event.priority,
      );
      emit(state.copyWith(task: task, isUpdatingTask: false));
    } on ApiException catch (e) {
      emit(
        state.copyWith(isUpdatingTask: false, actionErrorMessage: e.message),
      );
    }
  }

  Future<void> _onAssigneeChanged(
    TaskDetailAssigneeChanged event,
    Emitter<TaskDetailState> emit,
  ) async {
    final taskId = _taskId;
    if (taskId == null) return;
    emit(state.copyWith(isUpdatingTask: true, actionErrorMessage: null));
    try {
      final task = await _taskRepository.update(
        taskId,
        assignedToUserId: event.assignedToUserId,
      );
      emit(state.copyWith(task: task, isUpdatingTask: false));
    } on ApiException catch (e) {
      emit(
        state.copyWith(isUpdatingTask: false, actionErrorMessage: e.message),
      );
    }
  }

  Future<void> _onCommentAdded(
    TaskDetailCommentAdded event,
    Emitter<TaskDetailState> emit,
  ) async {
    final taskId = _taskId;
    if (taskId == null) return;
    emit(state.copyWith(isSubmittingComment: true, actionErrorMessage: null));
    try {
      final comment = await _taskRepository.addComment(taskId, event.body);
      emit(
        state.copyWith(
          comments: [...state.comments, comment],
          isSubmittingComment: false,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isSubmittingComment: false,
          actionErrorMessage: e.message,
        ),
      );
    }
  }

  /// [PhotoPickerField] has already done presign+PUT+attach as one call by
  /// the time this event fires (see `UploadRepository.captureUploadAndAttach`)
  /// — this just appends the server-confirmed photo, no repository call.
  void _onPhotoAttached(
    TaskDetailPhotoAttached event,
    Emitter<TaskDetailState> emit,
  ) {
    emit(state.copyWith(photos: [...state.photos, event.photo]));
  }
}
