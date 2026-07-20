import 'package:equatable/equatable.dart';

import '../data/team_models.dart';

enum AssignmentFormStatus {
  initial,
  loadingProjects,
  projectsReady,
  submitting,
  success,
  failure,
}

/// State for [AssignmentFormBloc].
class AssignmentFormState extends Equatable {
  const AssignmentFormState({
    this.status = AssignmentFormStatus.initial,
    this.projects = const [],
    this.savedAssignment,
    this.errorMessage,
  });

  final AssignmentFormStatus status;
  final List<ProjectSummary> projects;
  final Assignment? savedAssignment;
  final String? errorMessage;

  AssignmentFormState copyWith({
    AssignmentFormStatus? status,
    List<ProjectSummary>? projects,
    Assignment? savedAssignment,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AssignmentFormState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      savedAssignment: savedAssignment ?? this.savedAssignment,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    projects,
    savedAssignment,
    errorMessage,
  ];
}
