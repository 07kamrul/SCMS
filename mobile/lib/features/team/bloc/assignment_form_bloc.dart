import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/team_repository.dart';
import 'assignment_form_event.dart';
import 'assignment_form_state.dart';

/// Drives the assignment form: loads the project picker, then creates,
/// ends, or transfers an assignment.
class AssignmentFormBloc extends Bloc<AssignmentFormEvent, AssignmentFormState> {
  AssignmentFormBloc(this._repository) : super(const AssignmentFormState()) {
    on<AssignmentFormProjectsRequested>(_onProjectsRequested);
    on<AssignmentCreateSubmitted>(_onCreateSubmitted);
    on<AssignmentEndSubmitted>(_onEndSubmitted);
    on<AssignmentTransferSubmitted>(_onTransferSubmitted);
  }

  final TeamRepository _repository;

  Future<void> _onProjectsRequested(
    AssignmentFormProjectsRequested event,
    Emitter<AssignmentFormState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AssignmentFormStatus.loadingProjects,
        clearError: true,
      ),
    );
    try {
      final projects = await _repository.listProjectsForPicker();
      emit(
        state.copyWith(
          status: AssignmentFormStatus.projectsReady,
          projects: projects,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: AssignmentFormStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }

  Future<void> _onCreateSubmitted(
    AssignmentCreateSubmitted event,
    Emitter<AssignmentFormState> emit,
  ) async {
    emit(state.copyWith(status: AssignmentFormStatus.submitting, clearError: true));
    try {
      final assignment = await _repository.createAssignment(
        projectId: event.projectId,
        userId: event.userId,
        role: event.role,
      );
      emit(
        state.copyWith(
          status: AssignmentFormStatus.success,
          savedAssignment: assignment,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: AssignmentFormStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }

  Future<void> _onEndSubmitted(
    AssignmentEndSubmitted event,
    Emitter<AssignmentFormState> emit,
  ) async {
    emit(state.copyWith(status: AssignmentFormStatus.submitting, clearError: true));
    try {
      final assignment = await _repository.endAssignment(event.assignmentId);
      emit(
        state.copyWith(
          status: AssignmentFormStatus.success,
          savedAssignment: assignment,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: AssignmentFormStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }

  Future<void> _onTransferSubmitted(
    AssignmentTransferSubmitted event,
    Emitter<AssignmentFormState> emit,
  ) async {
    emit(state.copyWith(status: AssignmentFormStatus.submitting, clearError: true));
    try {
      final assignment = await _repository.transferAssignment(
        event.assignmentId,
        newProjectId: event.newProjectId,
        role: event.role,
      );
      emit(
        state.copyWith(
          status: AssignmentFormStatus.success,
          savedAssignment: assignment,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: AssignmentFormStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }
}
