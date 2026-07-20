import 'package:equatable/equatable.dart';

import '../data/issue_models.dart';

/// Events consumed by [IssueDetailBloc].
sealed class IssueDetailEvent extends Equatable {
  const IssueDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the detail page is shown — loads the issue, its status
/// history, comments, and photos together.
final class IssueDetailStarted extends IssueDetailEvent {
  const IssueDetailStarted(this.issueId);

  final String issueId;

  @override
  List<Object?> get props => [issueId];
}

/// Pull-to-refresh: reloads everything for the current issue.
final class IssueDetailRefreshed extends IssueDetailEvent {
  const IssueDetailRefreshed();
}

/// Fired when the user picks a new status. [note] is only sent when the
/// UI's "reason for status change" field was shown and filled in.
final class IssueDetailStatusChanged extends IssueDetailEvent {
  const IssueDetailStatusChanged(this.status, {this.note});

  final IssueStatus status;
  final String? note;

  @override
  List<Object?> get props => [status, note];
}

final class IssueDetailPriorityChanged extends IssueDetailEvent {
  const IssueDetailPriorityChanged(this.priority);

  final IssuePriority priority;

  @override
  List<Object?> get props => [priority];
}

final class IssueDetailCategoryChanged extends IssueDetailEvent {
  const IssueDetailCategoryChanged(this.category);

  final IssueCategory category;

  @override
  List<Object?> get props => [category];
}

/// [userId] is null to unassign.
final class IssueDetailAssigneeChanged extends IssueDetailEvent {
  const IssueDetailAssigneeChanged(this.userId);

  final String? userId;

  @override
  List<Object?> get props => [userId];
}

final class IssueDetailCommentAdded extends IssueDetailEvent {
  const IssueDetailCommentAdded(this.body);

  final String body;

  @override
  List<Object?> get props => [body];
}

/// Fired once [PhotoPickerField] has already completed the full
/// presign+PUT+attach call for a new photo — this just appends the
/// already-server-confirmed [photo] to the visible grid; no further network
/// call is made here.
final class IssueDetailPhotoAttached extends IssueDetailEvent {
  const IssueDetailPhotoAttached(this.photo);

  final IssuePhoto photo;

  @override
  List<Object?> get props => [photo];
}
