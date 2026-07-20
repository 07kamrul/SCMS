import 'package:equatable/equatable.dart';
import 'package:mobile/core/auth/permission.dart';

import '../data/team_models.dart';

/// Events consumed by [TeamListBloc].
sealed class TeamListEvent extends Equatable {
  const TeamListEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the list page is first shown; (re)loads page 1.
final class TeamListStarted extends TeamListEvent {
  const TeamListStarted();
}

/// Pull-to-refresh: reloads page 1 with the current filters.
final class TeamListRefreshed extends TeamListEvent {
  const TeamListRefreshed();
}

/// Fired on scroll-to-bottom to load the next page of the current filters.
final class TeamListNextPageRequested extends TeamListEvent {
  const TeamListNextPageRequested();
}

/// Changes the server-side role filter and reloads from page 1.
final class TeamListRoleFilterChanged extends TeamListEvent {
  const TeamListRoleFilterChanged(this.role);

  final Role? role;

  @override
  List<Object?> get props => [role];
}

/// Changes the client-side status filter (the backend's `GET /users` has no
/// status query param — see `app/api/v1/users.py`) applied over already
/// loaded pages.
final class TeamListStatusFilterChanged extends TeamListEvent {
  const TeamListStatusFilterChanged(this.status);

  final UserStatus? status;

  @override
  List<Object?> get props => [status];
}

/// Changes the free-text search filter and reloads from page 1.
final class TeamListSearchChanged extends TeamListEvent {
  const TeamListSearchChanged(this.search);

  final String search;

  @override
  List<Object?> get props => [search];
}

/// Deactivates or activates [userId] (toggling on its current status), then
/// reloads the current page in place.
final class TeamListUserStatusToggled extends TeamListEvent {
  const TeamListUserStatusToggled(this.userId, {required this.activate});

  final String userId;
  final bool activate;

  @override
  List<Object?> get props => [userId, activate];
}
