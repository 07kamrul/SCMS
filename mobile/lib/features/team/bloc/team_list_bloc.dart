import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/team_repository.dart';
import 'team_list_event.dart';
import 'team_list_state.dart';

/// Loads and paginates the company's user roster (`GET /users`), with a
/// server-side role/search filter and a client-side status filter (the
/// backend has no status query param). Also drives the deactivate/activate
/// action and reloads afterwards.
class TeamListBloc extends Bloc<TeamListEvent, TeamListState> {
  TeamListBloc(this._repository) : super(const TeamListState()) {
    on<TeamListStarted>(_onStarted);
    on<TeamListRefreshed>(_onRefreshed);
    on<TeamListNextPageRequested>(_onNextPageRequested);
    on<TeamListRoleFilterChanged>(_onRoleFilterChanged);
    on<TeamListStatusFilterChanged>(_onStatusFilterChanged);
    on<TeamListSearchChanged>(_onSearchChanged);
    on<TeamListUserStatusToggled>(_onUserStatusToggled);
  }

  static const _pageSize = 20;

  final TeamRepository _repository;

  Future<void> _onStarted(
    TeamListStarted event,
    Emitter<TeamListState> emit,
  ) => _loadFirstPage(emit);

  Future<void> _onRefreshed(
    TeamListRefreshed event,
    Emitter<TeamListState> emit,
  ) => _loadFirstPage(emit);

  Future<void> _onRoleFilterChanged(
    TeamListRoleFilterChanged event,
    Emitter<TeamListState> emit,
  ) => _loadFirstPage(emit, roleOverride: event.role, clearRole: event.role == null);

  Future<void> _onStatusFilterChanged(
    TeamListStatusFilterChanged event,
    Emitter<TeamListState> emit,
  ) async {
    emit(
      state.copyWith(
        statusFilter: event.status,
        clearStatusFilter: event.status == null,
      ),
    );
  }

  Future<void> _onSearchChanged(
    TeamListSearchChanged event,
    Emitter<TeamListState> emit,
  ) => _loadFirstPage(emit, searchOverride: event.search);

  Future<void> _loadFirstPage(
    Emitter<TeamListState> emit, {
    Role? roleOverride,
    bool clearRole = false,
    String? searchOverride,
  }) async {
    emit(
      state.copyWith(
        status: TeamListStatus.loading,
        clearError: true,
        roleFilter: roleOverride,
        clearRoleFilter: clearRole,
        search: searchOverride,
      ),
    );
    try {
      final result = await _repository.listUsers(
        page: 1,
        pageSize: _pageSize,
        role: state.roleFilter,
        search: state.search.isEmpty ? null : state.search,
      );
      emit(
        state.copyWith(
          status: TeamListStatus.success,
          users: result.users,
          page: 1,
          hasReachedMax: result.users.length < _pageSize,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(status: TeamListStatus.failure, errorMessage: e.message));
    }
  }

  Future<void> _onNextPageRequested(
    TeamListNextPageRequested event,
    Emitter<TeamListState> emit,
  ) async {
    if (state.hasReachedMax || state.status == TeamListStatus.loading) return;
    try {
      final nextPage = state.page + 1;
      final result = await _repository.listUsers(
        page: nextPage,
        pageSize: _pageSize,
        role: state.roleFilter,
        search: state.search.isEmpty ? null : state.search,
      );
      emit(
        state.copyWith(
          status: TeamListStatus.success,
          users: [...state.users, ...result.users],
          page: nextPage,
          hasReachedMax: result.users.length < _pageSize,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> _onUserStatusToggled(
    TeamListUserStatusToggled event,
    Emitter<TeamListState> emit,
  ) async {
    emit(state.copyWith(isMutating: true, clearError: true));
    try {
      final updated = event.activate
          ? await _repository.activateUser(event.userId)
          : await _repository.deactivateUser(event.userId);
      final users = state.users
          .map((user) => user.id == updated.id ? updated : user)
          .toList();
      emit(state.copyWith(users: users, isMutating: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isMutating: false, errorMessage: e.message));
    }
  }
}
