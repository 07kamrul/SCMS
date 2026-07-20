import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../bloc/tasks_list_bloc.dart';
import '../bloc/tasks_list_event.dart';
import '../bloc/tasks_list_state.dart';
import '../data/task_models.dart';
import 'task_detail_page.dart';
import 'task_form_page.dart';

/// Task list for a project (or, when [projectId] is null, every task
/// visible to the current user), with status/priority/overdue filter chips
/// and infinite scroll.
///
/// Permission flags ([canCreate], [canApprove], [canReassign]) are supplied
/// by the caller — this page never computes them itself — and are simply
/// forwarded to [TaskDetailPage] / used to decide whether the create FAB
/// shows.
class TasksListPage extends StatelessWidget {
  const TasksListPage({
    super.key,
    this.projectId,
    this.canCreate = false,
    this.canApprove = false,
    this.canReassign = false,
  });

  final String? projectId;
  final bool canCreate;
  final bool canApprove;
  final bool canReassign;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TasksListBloc>(
      create: (_) => getIt<TasksListBloc>()
        ..add(TasksListSubscriptionRequested(projectId: projectId)),
      child: _TasksListView(
        projectId: projectId,
        canCreate: canCreate,
        canApprove: canApprove,
        canReassign: canReassign,
      ),
    );
  }
}

class _TasksListView extends StatefulWidget {
  const _TasksListView({
    required this.projectId,
    required this.canCreate,
    required this.canApprove,
    required this.canReassign,
  });

  final String? projectId;
  final bool canCreate;
  final bool canApprove;
  final bool canReassign;

  @override
  State<_TasksListView> createState() => _TasksListViewState();
}

class _TasksListViewState extends State<_TasksListView> {
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
    context.read<TasksListBloc>().add(const TasksListNextPageRequested());
  }

  Future<void> _openTask(BuildContext context, Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailPage(
          taskId: task.id,
          canApprove: widget.canApprove,
          canReassign: widget.canReassign,
        ),
      ),
    );
    if (context.mounted) {
      context.read<TasksListBloc>().add(const TasksListRefreshed());
    }
  }

  Future<void> _openCreateForm(BuildContext context) async {
    final projectId = widget.projectId;
    if (projectId == null) return;
    final bloc = context.read<TasksListBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TaskFormPage(projectId: projectId)),
    );
    if (context.mounted) {
      bloc.add(const TasksListRefreshed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          const _FilterChips(),
          Expanded(
            child: BlocBuilder<TasksListBloc, TasksListState>(
              builder: (context, state) {
                if (state.isLoading && state.tasks.isEmpty) {
                  return const LoadingView();
                }
                if (state.errorMessage != null && state.tasks.isEmpty) {
                  return ErrorView(
                    message: state.errorMessage!,
                    onRetry: () => context.read<TasksListBloc>().add(
                      const TasksListRefreshed(),
                    ),
                  );
                }
                if (state.tasks.isEmpty) {
                  return const Center(child: Text('No tasks found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<TasksListBloc>().add(
                      const TasksListRefreshed(),
                    );
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: state.tasks.length + (state.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= state.tasks.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final task = state.tasks[index];
                      return _TaskListTile(
                        task: task,
                        onTap: () => _openTask(context, task),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.canCreate && widget.projectId != null
          ? FloatingActionButton(
              onPressed: () => _openCreateForm(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TasksListBloc, TasksListState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _statusDropdown(context, state.statusFilter),
              const SizedBox(width: AppSpacing.sm),
              _priorityDropdown(context, state.priorityFilter),
              const SizedBox(width: AppSpacing.sm),
              FilterChip(
                label: const Text('Overdue only'),
                selected: state.overdueOnly,
                onSelected: (selected) => context.read<TasksListBloc>().add(
                  TasksListOverdueFilterToggled(selected),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusDropdown(BuildContext context, TaskStatus? current) {
    return DropdownButton<TaskStatus?>(
      value: current,
      hint: const Text('Status'),
      items: [
        const DropdownMenuItem<TaskStatus?>(value: null, child: Text('All statuses')),
        for (final status in TaskStatus.values)
          DropdownMenuItem<TaskStatus?>(value: status, child: Text(status.label)),
      ],
      onChanged: (value) => context.read<TasksListBloc>().add(
        TasksListStatusFilterChanged(value),
      ),
    );
  }

  Widget _priorityDropdown(BuildContext context, TaskPriority? current) {
    return DropdownButton<TaskPriority?>(
      value: current,
      hint: const Text('Priority'),
      items: [
        const DropdownMenuItem<TaskPriority?>(
          value: null,
          child: Text('All priorities'),
        ),
        for (final priority in TaskPriority.values)
          DropdownMenuItem<TaskPriority?>(
            value: priority,
            child: Text(priority.label),
          ),
      ],
      onChanged: (value) => context.read<TasksListBloc>().add(
        TasksListPriorityFilterChanged(value),
      ),
    );
  }
}

class _TaskListTile extends StatelessWidget {
  const _TaskListTile({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            _Chip(label: task.status.label, color: task.status.color),
            const SizedBox(width: AppSpacing.xs),
            _Chip(label: task.priority.label, color: task.priority.color),
            if (task.dueDate != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(DateFormat.yMMMd().format(task.dueDate!.toLocal())),
            ],
          ],
        ),
        trailing: task.isOverdue
            ? Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error)
            : null,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.mdAll,
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
