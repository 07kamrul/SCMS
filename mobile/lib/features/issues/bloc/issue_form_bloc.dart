import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/issue_repository.dart';
import 'issue_form_event.dart';
import 'issue_form_state.dart';

/// Owns the create-issue form. Reads `IssueFormState.assignableUsers` from
/// whatever the caller seeded it with at construction time — this bloc
/// never fetches a user directory itself.
class IssueFormBloc extends Bloc<IssueFormEvent, IssueFormState> {
  IssueFormBloc(this._issueRepository, {List<IssueAssignee> assignableUsers = const []})
    : super(IssueFormState(assignableUsers: assignableUsers)) {
    on<IssueFormTitleChanged>(
      (event, emit) => emit(state.copyWith(title: event.title)),
    );
    on<IssueFormDescriptionChanged>(
      (event, emit) => emit(state.copyWith(description: event.description)),
    );
    on<IssueFormCategoryChanged>(
      (event, emit) => emit(state.copyWith(category: event.category)),
    );
    on<IssueFormPriorityChanged>(
      (event, emit) => emit(state.copyWith(priority: event.priority)),
    );
    on<IssueFormAssigneeChanged>(
      (event, emit) => emit(
        state.copyWith(
          assignedToUserId: event.userId,
          clearAssignedToUserId: event.userId == null,
        ),
      ),
    );
    on<IssueFormSubmitted>(_onSubmitted);
  }

  final IssueRepository _issueRepository;

  Future<void> _onSubmitted(
    IssueFormSubmitted event,
    Emitter<IssueFormState> emit,
  ) async {
    if (!state.isValid) return;
    emit(state.copyWith(status: IssueFormStatus.submitting));
    try {
      final issue = await _issueRepository.create(
        projectId: event.projectId,
        title: state.title.trim(),
        description: state.description.trim().isEmpty
            ? null
            : state.description.trim(),
        category: state.category!,
        priority: state.priority,
        assignedToUserId: state.assignedToUserId,
      );
      emit(
        state.copyWith(status: IssueFormStatus.success, createdIssue: issue),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(status: IssueFormStatus.failure, errorMessage: e.message));
    }
  }
}
