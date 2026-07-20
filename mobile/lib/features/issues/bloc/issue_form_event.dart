import 'package:equatable/equatable.dart';

import '../data/issue_models.dart';

/// Events consumed by [IssueFormBloc].
sealed class IssueFormEvent extends Equatable {
  const IssueFormEvent();

  @override
  List<Object?> get props => [];
}

final class IssueFormTitleChanged extends IssueFormEvent {
  const IssueFormTitleChanged(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

final class IssueFormDescriptionChanged extends IssueFormEvent {
  const IssueFormDescriptionChanged(this.description);

  final String description;

  @override
  List<Object?> get props => [description];
}

final class IssueFormCategoryChanged extends IssueFormEvent {
  const IssueFormCategoryChanged(this.category);

  final IssueCategory category;

  @override
  List<Object?> get props => [category];
}

final class IssueFormPriorityChanged extends IssueFormEvent {
  const IssueFormPriorityChanged(this.priority);

  final IssuePriority priority;

  @override
  List<Object?> get props => [priority];
}

/// [userId] is null for "unassigned".
final class IssueFormAssigneeChanged extends IssueFormEvent {
  const IssueFormAssigneeChanged(this.userId);

  final String? userId;

  @override
  List<Object?> get props => [userId];
}

final class IssueFormSubmitted extends IssueFormEvent {
  const IssueFormSubmitted(this.projectId);

  final String projectId;

  @override
  List<Object?> get props => [projectId];
}
