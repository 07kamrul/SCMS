import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/loading_view.dart';

import '../bloc/team_list_bloc.dart';
import '../bloc/team_list_event.dart';
import '../bloc/team_list_state.dart';
import '../data/team_models.dart';
import 'user_detail_page.dart';
import 'user_form_page.dart';

/// Lists the company's users with role/status filters and search. Tapping a
/// row opens [UserDetailPage]; the FAB (shown only when [canCreateUser])
/// opens [UserFormPage] in create mode.
///
/// Capability flags are plain booleans rather than a permission-checking
/// service so this widget stays independently testable; the caller decides
/// what the current user is allowed to do.
class TeamListPage extends StatelessWidget {
  const TeamListPage({
    super.key,
    required this.canCreateUser,
    required this.canUpdateUser,
    required this.canDeactivateUsers,
    required this.canManageAssignments,
  });

  final bool canCreateUser;
  final bool canUpdateUser;
  final bool canDeactivateUsers;
  final bool canManageAssignments;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TeamListBloc>()..add(const TeamListStarted()),
      child: _TeamListView(
        canCreateUser: canCreateUser,
        canUpdateUser: canUpdateUser,
        canDeactivateUsers: canDeactivateUsers,
        canManageAssignments: canManageAssignments,
      ),
    );
  }
}

class _TeamListView extends StatefulWidget {
  const _TeamListView({
    required this.canCreateUser,
    required this.canUpdateUser,
    required this.canDeactivateUsers,
    required this.canManageAssignments,
  });

  final bool canCreateUser;
  final bool canUpdateUser;
  final bool canDeactivateUsers;
  final bool canManageAssignments;

  @override
  State<_TeamListView> createState() => _TeamListViewState();
}

class _TeamListViewState extends State<_TeamListView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final nearBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200;
    if (nearBottom) {
      context.read<TeamListBloc>().add(const TeamListNextPageRequested());
    }
  }

  Future<void> _openCreateForm(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const UserFormPage()),
    );
    if (!mounted) return;
    context.read<TeamListBloc>().add(const TeamListRefreshed());
  }

  Future<void> _openDetail(BuildContext context, TeamUser user) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UserDetailPage(
          userId: user.id,
          canUpdateUser: widget.canUpdateUser,
          canManageAssignments: widget.canManageAssignments,
        ),
      ),
    );
    if (!mounted) return;
    context.read<TeamListBloc>().add(const TeamListRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: widget.canCreateUser
          ? FloatingActionButton(
              onPressed: () => _openCreateForm(context),
              child: const Icon(Icons.person_add),
            )
          : null,
      body: SafeArea(
        child: BlocConsumer<TeamListBloc, TeamListState>(
          listenWhen: (previous, current) =>
              current.errorMessage != null &&
              current.errorMessage != previous.errorMessage,
          listener: (context, state) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          },
          builder: (context, state) {
            return Column(
              children: [
                _FilterBar(searchController: _searchController),
                Expanded(child: _buildList(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, TeamListState state) {
    if (state.status == TeamListStatus.loading && state.users.isEmpty) {
      return const LoadingView();
    }
    final users = state.visibleUsers;
    if (state.status != TeamListStatus.loading && users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }
    return RefreshIndicator(
      onRefresh: () async {
        context.read<TeamListBloc>().add(const TeamListRefreshed());
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: users.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final user = users[index];
          return _UserTile(
            user: user,
            canDeactivateUsers: widget.canDeactivateUsers,
            isMutating: state.isMutating,
            onTap: () => _openDetail(context, user),
            onToggleStatus: () => context.read<TeamListBloc>().add(
              TeamListUserStatusToggled(
                user.id,
                activate: user.status != UserStatus.active,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TeamListBloc>().state;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by name',
              isDense: true,
            ),
            onSubmitted: (value) => context.read<TeamListBloc>().add(
              TeamListSearchChanged(value.trim()),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Role?>(
                  initialValue: state.roleFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All roles')),
                    ...Role.values.map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.value),
                      ),
                    ),
                  ],
                  onChanged: (role) => context.read<TeamListBloc>().add(
                    TeamListRoleFilterChanged(role),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<UserStatus?>(
                  initialValue: state.statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All statuses')),
                    ...UserStatus.values.map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.value),
                      ),
                    ),
                  ],
                  onChanged: (status) => context.read<TeamListBloc>().add(
                    TeamListStatusFilterChanged(status),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.canDeactivateUsers,
    required this.isMutating,
    required this.onTap,
    required this.onToggleStatus,
  });

  final TeamUser user;
  final bool canDeactivateUsers;
  final bool isMutating;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final isActive = user.status == UserStatus.active;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(user.fullName),
        subtitle: Text(user.jobTitle ?? user.email ?? user.phone ?? ''),
        leading: CircleAvatar(
          backgroundImage: user.profilePhotoUrl != null
              ? NetworkImage(user.profilePhotoUrl!)
              : null,
          child: user.profilePhotoUrl == null
              ? Text(user.fullName.isNotEmpty ? user.fullName[0] : '?')
              : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoleChip(role: user.role),
            const SizedBox(width: AppSpacing.xs),
            UserStatusChip(status: user.status),
            if (canDeactivateUsers) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: isActive ? 'Deactivate' : 'Activate',
                icon: Icon(isActive ? Icons.block : Icons.check_circle_outline),
                onPressed: isMutating ? null : onToggleStatus,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small colored chip for a [Role] value, shared by list/detail pages.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role});

  final Role role;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(role.value, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// A small colored chip for a [UserStatus] value: active = green,
/// inactive = grey, suspended = red.
class UserStatusChip extends StatelessWidget {
  const UserStatusChip({super.key, required this.status});

  final UserStatus status;

  Color _color() {
    switch (status) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.inactive:
        return Colors.grey;
      case UserStatus.suspended:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Chip(
      label: Text(
        status.value,
        style: TextStyle(fontSize: 11, color: color),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
