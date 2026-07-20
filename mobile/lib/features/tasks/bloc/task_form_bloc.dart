import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_queue_repository.dart';
import '../data/task_repository.dart';
import 'task_form_event.dart';
import 'task_form_state.dart';

/// Owns the create-task form's field state and submission.
///
/// Deliberately decoupled from the `team` feature: the caller supplies the
/// list of [AssignableUser]s (via [TaskFormInitialized]) instead of this
/// bloc fetching them itself.
class TaskFormBloc extends Bloc<TaskFormEvent, TaskFormState> {
  TaskFormBloc(this._taskRepository, {OfflineQueueRepository? queueRepository})
    : _queueRepository = queueRepository ?? OfflineQueueRepository(),
      super(const TaskFormState()) {
    on<TaskFormInitialized>(_onInitialized);
    on<TaskFormTitleChanged>(_onTitleChanged);
    on<TaskFormDescriptionChanged>(_onDescriptionChanged);
    on<TaskFormPriorityChanged>(_onPriorityChanged);
    on<TaskFormDueDateChanged>(_onDueDateChanged);
    on<TaskFormAssigneeChanged>(_onAssigneeChanged);
    on<TaskFormSubmitted>(_onSubmitted);
  }

  final TaskRepository _taskRepository;
  final OfflineQueueRepository _queueRepository;

  void _onInitialized(TaskFormInitialized event, Emitter<TaskFormState> emit) {
    emit(
      state.copyWith(
        projectId: event.projectId,
        assignableUsers: event.assignableUsers,
      ),
    );
  }

  void _onTitleChanged(TaskFormTitleChanged event, Emitter<TaskFormState> emit) {
    emit(state.copyWith(title: event.title));
  }

  void _onDescriptionChanged(
    TaskFormDescriptionChanged event,
    Emitter<TaskFormState> emit,
  ) {
    emit(state.copyWith(description: event.description));
  }

  void _onPriorityChanged(
    TaskFormPriorityChanged event,
    Emitter<TaskFormState> emit,
  ) {
    emit(state.copyWith(priority: event.priority));
  }

  void _onDueDateChanged(
    TaskFormDueDateChanged event,
    Emitter<TaskFormState> emit,
  ) {
    emit(state.copyWith(dueDate: event.dueDate));
  }

  void _onAssigneeChanged(
    TaskFormAssigneeChanged event,
    Emitter<TaskFormState> emit,
  ) {
    emit(state.copyWith(assignedToUserId: event.assignedToUserId));
  }

  Future<void> _onSubmitted(
    TaskFormSubmitted event,
    Emitter<TaskFormState> emit,
  ) async {
    if (!state.isValid || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    try {
      final task = await _taskRepository.create(
        projectId: state.projectId,
        title: state.title.trim(),
        description: state.description.trim().isEmpty
            ? null
            : state.description.trim(),
        priority: state.priority,
        assignedToUserId: state.assignedToUserId,
        dueDate: state.dueDate,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          createdTask: task,
        ),
      );
    } on ApiException catch (e) {
      if (e.errorCode == 'network_error') {
        await _queueRepository.enqueueSubmission(
          kind: 'task_status',
          jsonPayload: jsonEncode({
            'project_id': state.projectId,
            'title': state.title.trim(),
            'description': state.description.trim().isEmpty
                ? null
                : state.description.trim(),
            'priority': state.priority.value,
            'assigned_to_user_id': state.assignedToUserId,
            'due_date': state.dueDate?.toIso8601String(),
          }),
        );
        emit(state.copyWith(isSubmitting: false, isOfflineQueued: true));
        return;
      }
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }
}
