import 'package:equatable/equatable.dart';

import '../data/issue_models.dart';

/// Events consumed by [IssuesListBloc].
sealed class IssuesListEvent extends Equatable {
  const IssuesListEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the list page is first shown (or re-shown for a
/// different project) — resets pagination and loads page 1.
final class IssuesListStarted extends IssuesListEvent {
  const IssuesListStarted({this.projectId});

  final String? projectId;

  @override
  List<Object?> get props => [projectId];
}

/// Pull-to-refresh: reloads page 1 with the current filters, keeping
/// whatever is currently on screen visible until the new page arrives.
final class IssuesListRefreshed extends IssuesListEvent {
  const IssuesListRefreshed();
}

/// Fired when the list scrolls near the bottom — loads the next page and
/// appends it to the current items.
final class IssuesListNextPageRequested extends IssuesListEvent {
  const IssuesListNextPageRequested();
}

/// Fired when the user changes a filter chip. Always carries the full,
/// desired filter set — `null` for a filter means "no filter" (show all),
/// not "leave unchanged".
final class IssuesListFilterChanged extends IssuesListEvent {
  const IssuesListFilterChanged({
    this.status,
    this.priority,
    this.category,
  });

  final IssueStatus? status;
  final IssuePriority? priority;
  final IssueCategory? category;

  @override
  List<Object?> get props => [status, priority, category];
}
