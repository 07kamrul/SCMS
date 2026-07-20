import 'package:equatable/equatable.dart';

import '../data/team_models.dart';

/// Events consumed by [AssignmentFormBloc].
sealed class AssignmentFormEvent extends Equatable {
  const AssignmentFormEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the project picker options (`GET /projects`).
final class AssignmentFormProjectsRequested extends AssignmentFormEvent {
  const AssignmentFormProjectsRequested();
}

/// Assigns [userId] to [projectId] with [role] (`POST /assignments`).
final class AssignmentCreateSubmitted extends AssignmentFormEvent {
  const AssignmentCreateSubmitted({
    required this.projectId,
    required this.userId,
    required this.role,
  });

  final String projectId;
  final String userId;
  final AssignmentRole role;

  @override
  List<Object?> get props => [projectId, userId, role];
}

/// Ends an active assignment (`POST /assignments/{id}/end`).
final class AssignmentEndSubmitted extends AssignmentFormEvent {
  const AssignmentEndSubmitted(this.assignmentId);

  final String assignmentId;

  @override
  List<Object?> get props => [assignmentId];
}

/// Ends the current assignment and starts a new one on another project
/// (`POST /assignments/{id}/transfer`).
final class AssignmentTransferSubmitted extends AssignmentFormEvent {
  const AssignmentTransferSubmitted({
    required this.assignmentId,
    required this.newProjectId,
    required this.role,
  });

  final String assignmentId;
  final String newProjectId;
  final AssignmentRole role;

  @override
  List<Object?> get props => [assignmentId, newProjectId, role];
}
