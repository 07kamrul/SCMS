import 'package:equatable/equatable.dart';
import 'package:mobile/core/auth/permission.dart';

import '../data/team_models.dart';

enum TeamListStatus { initial, loading, success, failure }

/// State for [TeamListBloc]. [users] always holds every user loaded so far
/// (across pages); [visibleUsers] applies the client-side [statusFilter] on
/// top of that.
class TeamListState extends Equatable {
  const TeamListState({
    this.status = TeamListStatus.initial,
    this.users = const [],
    this.page = 1,
    this.hasReachedMax = false,
    this.roleFilter,
    this.statusFilter,
    this.search = '',
    this.errorMessage,
    this.isMutating = false,
  });

  final TeamListStatus status;
  final List<TeamUser> users;
  final int page;
  final bool hasReachedMax;
  final Role? roleFilter;
  final UserStatus? statusFilter;
  final String search;
  final String? errorMessage;

  /// True while a deactivate/activate action is in flight, so the list can
  /// disable its action buttons without showing a full-page spinner.
  final bool isMutating;

  List<TeamUser> get visibleUsers {
    if (statusFilter == null) return users;
    return users.where((user) => user.status == statusFilter).toList();
  }

  TeamListState copyWith({
    TeamListStatus? status,
    List<TeamUser>? users,
    int? page,
    bool? hasReachedMax,
    Role? roleFilter,
    bool clearRoleFilter = false,
    UserStatus? statusFilter,
    bool clearStatusFilter = false,
    String? search,
    String? errorMessage,
    bool clearError = false,
    bool? isMutating,
  }) {
    return TeamListState(
      status: status ?? this.status,
      users: users ?? this.users,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      roleFilter: clearRoleFilter ? null : (roleFilter ?? this.roleFilter),
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      search: search ?? this.search,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isMutating: isMutating ?? this.isMutating,
    );
  }

  @override
  List<Object?> get props => [
    status,
    users,
    page,
    hasReachedMax,
    roleFilter,
    statusFilter,
    search,
    errorMessage,
    isMutating,
  ];
}
