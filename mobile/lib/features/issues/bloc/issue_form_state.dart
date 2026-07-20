import 'package:equatable/equatable.dart';

import '../data/issue_models.dart';

enum IssueFormStatus { editing, submitting, success, failure }

/// A user this issue can be assigned to. Kept as a tiny local shape (rather
/// than importing a `team`/user-directory feature) — callers that already
/// have a project's team roster loaded (e.g. a project detail page) pass
/// the list in; this feature never fetches it itself.
class IssueAssignee extends Equatable {
  const IssueAssignee({required this.id, required this.displayName});

  final String id;
  final String displayName;

  @override
  List<Object?> get props => [id, displayName];
}

/// State for the create-issue form.
class IssueFormState extends Equatable {
  const IssueFormState({
    this.title = '',
    this.description = '',
    this.category,
    this.priority = IssuePriority.medium,
    this.assignedToUserId,
    this.assignableUsers = const [],
    this.status = IssueFormStatus.editing,
    this.errorMessage,
    this.createdIssue,
  });

  final String title;
  final String description;
  final IssueCategory? category;
  final IssuePriority priority;
  final String? assignedToUserId;
  final List<IssueAssignee> assignableUsers;
  final IssueFormStatus status;
  final String? errorMessage;
  final Issue? createdIssue;

  /// Category is required by the backend (`IssueCreate.category` has no
  /// default) and title must be non-empty.
  bool get isValid => title.trim().isNotEmpty && category != null;

  IssueFormState copyWith({
    String? title,
    String? description,
    IssueCategory? category,
    IssuePriority? priority,
    String? assignedToUserId,
    bool clearAssignedToUserId = false,
    List<IssueAssignee>? assignableUsers,
    IssueFormStatus? status,
    String? errorMessage,
    Issue? createdIssue,
  }) {
    return IssueFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      assignedToUserId: clearAssignedToUserId
          ? null
          : (assignedToUserId ?? this.assignedToUserId),
      assignableUsers: assignableUsers ?? this.assignableUsers,
      status: status ?? this.status,
      errorMessage: errorMessage,
      createdIssue: createdIssue ?? this.createdIssue,
    );
  }

  @override
  List<Object?> get props => [
    title,
    description,
    category,
    priority,
    assignedToUserId,
    assignableUsers,
    status,
    errorMessage,
    createdIssue,
  ];
}
