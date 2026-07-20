import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/auth/role_permissions.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_breakpoints.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/issues/presentation/issues_list_page.dart';
import 'package:mobile/features/notifications/presentation/notifications_list_page.dart';
import 'package:mobile/features/tasks/presentation/tasks_list_page.dart';
// Reused read-only for its wire values/label/color — this feature never
// writes to `features/tracking/*`.
import 'package:mobile/features/tracking/data/location_models.dart'
    show LocationStatus;
import 'package:mobile/shared/widgets/error_view.dart';
import 'package:mobile/shared/widgets/loading_view.dart';

import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../data/dashboard_models.dart';

/// Role-tailored "what needs my attention today" home screen, backed by
/// `GET /dashboard/me`.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardBloc>(
      create: (_) => getIt<DashboardBloc>()..add(const DashboardRequested()),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              final unread = state is DashboardLoaded
                  ? state.summary.unreadNotifications
                  : 0;
              final role = state is DashboardLoaded ? state.summary.role : null;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationsListPage(
                      canApproveTasks: role != null &&
                          hasPermission(role, Permission.taskApprove),
                      canReassignTasks: role != null &&
                          hasPermission(role, Permission.taskCreate),
                      canUpdateIssues: role != null &&
                          hasPermission(role, Permission.issueUpdate),
                      canUploadPhoto: role != null &&
                          hasPermission(role, Permission.photoUpload),
                    ),
                  ),
                ),
                icon: Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          return switch (state) {
            DashboardInitial() || DashboardLoading() => const LoadingView(),
            DashboardFailure(:final message) => ErrorView(
              message: message,
              onRetry: () =>
                  context.read<DashboardBloc>().add(const DashboardRequested()),
            ),
            DashboardLoaded(:final summary) => _DashboardBody(
              summary: summary,
            ),
          };
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final role = summary.role;
    final crossAxisCount = context.isCompact ? 2 : 4;
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(const DashboardRequested());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.5,
            children: [
              _CountCard(
                label: 'My Open Tasks',
                count: summary.myOpenTasks,
                icon: Icons.checklist_rtl,
                color: Colors.blue,
                onTap: () => _openTasks(context, role),
              ),
              _CountCard(
                label: 'Overdue Tasks',
                count: summary.myOverdueTasks,
                icon: Icons.warning_amber_rounded,
                color: Colors.red,
                onTap: () => _openTasks(context, role),
              ),
              _CountCard(
                label: 'My Open Issues',
                count: summary.myOpenIssues,
                icon: Icons.report_problem_outlined,
                color: Colors.orange,
                onTap: () => _openIssues(context, role),
              ),
              _CountCard(
                label: 'Visible Projects',
                count: summary.visibleProjectCount,
                icon: Icons.apartment_outlined,
                color: Colors.teal,
              ),
            ],
          ),
          if (summary.pendingTaskApprovals case final pendingApprovals?) ...[
            const SizedBox(height: AppSpacing.sm),
            _CountCard(
              label: 'Pending Task Approvals',
              count: pendingApprovals,
              icon: Icons.rule_folder_outlined,
              color: Colors.purple,
              onTap: () => _openTasks(context, role),
              fullWidth: true,
            ),
          ],
          if (summary.teamStatusCounts case final teamStatusCounts?) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Team Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _TeamStatusBreakdown(counts: teamStatusCounts),
          ],
        ],
      ),
    );
  }

  void _openTasks(BuildContext context, Role role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TasksListPage(
          canCreate: hasPermission(role, Permission.taskCreate),
          canApprove: hasPermission(role, Permission.taskApprove),
          // Mirrors the backend's own gating of `can_reassign` in
          // `app/api/v1/tasks.py` (tied to `TASK_CREATE`, not a separate
          // permission).
          canReassign: hasPermission(role, Permission.taskCreate),
        ),
      ),
    );
  }

  void _openIssues(BuildContext context, Role role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IssuesListPage(
          canCreate: hasPermission(role, Permission.issueCreate),
          canUpdateIssues: hasPermission(role, Permission.issueUpdate),
          canUploadPhoto: hasPermission(role, Permission.photoUpload),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
    this.fullWidth = false,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: fullWidth
              ? Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Compact breakdown of the team's current tracking status, zero-filled
/// across every `LocationStatus` value (not just the ones present in the
/// server's response) so a status with no members is still visible as 0.
class _TeamStatusBreakdown extends StatelessWidget {
  const _TeamStatusBreakdown({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final status in LocationStatus.values)
          Chip(
            avatar: CircleAvatar(backgroundColor: status.color, radius: 6),
            label: Text('${status.label}: ${counts[status.value] ?? 0}'),
          ),
      ],
    );
  }
}
