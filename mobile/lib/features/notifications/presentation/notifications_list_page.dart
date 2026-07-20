import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/features/issues/presentation/issue_detail_page.dart';
import 'package:mobile/features/tasks/presentation/task_detail_page.dart';
import 'package:mobile/shared/widgets/error_view.dart';
import 'package:mobile/shared/widgets/loading_view.dart';

import '../bloc/notifications_list_bloc.dart';
import '../bloc/notifications_list_event.dart';
import '../bloc/notifications_list_state.dart';
import '../data/notification_models.dart';

/// Notification types that route to [TaskDetailPage].
const _taskNotificationTypes = {'task.assigned', 'task.status_changed'};

/// Notification types that route to [IssueDetailPage].
const _issueNotificationTypes = {'issue.created', 'issue.status_changed'};

/// The current user's notification list: unread-only filter, infinite
/// scroll, tap-to-mark-read, and tap-to-navigate based on `type`/`entityId`.
///
/// Permission flags forwarded to the detail pages this list can navigate
/// into are supplied by the caller — this page never computes them itself,
/// same convention as `TasksListPage`/`IssuesListPage`.
class NotificationsListPage extends StatelessWidget {
  const NotificationsListPage({
    super.key,
    this.canApproveTasks = false,
    this.canReassignTasks = false,
    this.canUpdateIssues = false,
    this.canUploadPhoto = false,
  });

  final bool canApproveTasks;
  final bool canReassignTasks;
  final bool canUpdateIssues;
  final bool canUploadPhoto;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsListBloc>(
      create: (_) => getIt<NotificationsListBloc>()
        ..add(const NotificationsListSubscriptionRequested()),
      child: _NotificationsListView(
        canApproveTasks: canApproveTasks,
        canReassignTasks: canReassignTasks,
        canUpdateIssues: canUpdateIssues,
        canUploadPhoto: canUploadPhoto,
      ),
    );
  }
}

class _NotificationsListView extends StatefulWidget {
  const _NotificationsListView({
    required this.canApproveTasks,
    required this.canReassignTasks,
    required this.canUpdateIssues,
    required this.canUploadPhoto,
  });

  final bool canApproveTasks;
  final bool canReassignTasks;
  final bool canUpdateIssues;
  final bool canUploadPhoto;

  @override
  State<_NotificationsListView> createState() =>
      _NotificationsListViewState();
}

class _NotificationsListViewState extends State<_NotificationsListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    context.read<NotificationsListBloc>().add(
      const NotificationsListNextPageRequested(),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (notification.isUnread) {
      context.read<NotificationsListBloc>().add(
        NotificationsListMarkReadRequested(notification.id),
      );
    }

    final entityId = notification.entityId;
    if (entityId == null) return;

    if (_taskNotificationTypes.contains(notification.type)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TaskDetailPage(
            taskId: entityId,
            canApprove: widget.canApproveTasks,
            canReassign: widget.canReassignTasks,
          ),
        ),
      );
      return;
    }

    if (_issueNotificationTypes.contains(notification.type)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => IssueDetailPage(
            issueId: entityId,
            canUpdate: widget.canUpdateIssues,
            canUploadPhoto: widget.canUploadPhoto,
          ),
        ),
      );
      return;
    }

    // Unknown notification type — nothing to navigate to yet.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationsListBloc, NotificationsListState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: const Text('Unread only'),
                  selected: state.unreadOnly,
                  onSelected: (selected) => context
                      .read<NotificationsListBloc>()
                      .add(NotificationsListUnreadOnlyToggled(selected)),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsListBloc, NotificationsListState>(
        builder: (context, state) {
          if (state.isLoading && state.notifications.isEmpty) {
            return const LoadingView();
          }
          if (state.errorMessage != null && state.notifications.isEmpty) {
            return ErrorView(
              message: state.errorMessage!,
              onRetry: () => context.read<NotificationsListBloc>().add(
                const NotificationsListRefreshed(),
              ),
            );
          }
          if (state.notifications.isEmpty) {
            return const Center(child: Text('No notifications.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<NotificationsListBloc>().add(
                const NotificationsListRefreshed(),
              );
            },
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount:
                  state.notifications.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                if (index >= state.notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final notification = state.notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _openNotification(context, notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = notification.isUnread;
    return Card(
      color: isUnread
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: ListTile(
        onTap: onTap,
        leading: isUnread
            ? Icon(
                Icons.circle,
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              )
            : const SizedBox(width: 10),
        title: Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.body case final body?)
              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              DateFormat.yMMMd().add_jm().format(
                notification.createdAt.toLocal(),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
