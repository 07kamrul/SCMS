import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/features/uploads/data/upload_repository.dart';
import 'package:mobile/features/uploads/presentation/photo_picker_field.dart';
import 'package:mobile/shared/widgets/loading_view.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import '../bloc/task_detail_bloc.dart';
import '../bloc/task_detail_event.dart';
import '../bloc/task_detail_state.dart';
import '../data/task_models.dart';

/// Statuses that only a user with `task:approve` may move a task into.
const _approverOnlyStatuses = {
  TaskStatus.approved,
  TaskStatus.rejected,
  TaskStatus.completed,
};

const double _kMaxDetailWidth = 720;

/// Full task detail: info, an editable status control (gated by
/// [canApprove]), a reassign action (gated by [canReassign]), comments, and
/// photos.
class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.taskId,
    this.canApprove = false,
    this.canReassign = false,
  });

  final String taskId;
  final bool canApprove;
  final bool canReassign;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late final TaskDetailBloc _bloc;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bloc = getIt<TaskDetailBloc>()..add(TaskDetailLoadRequested(widget.taskId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _submitComment() {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    _bloc.add(TaskDetailCommentAdded(body));
    _commentController.clear();
  }

  void _onPhotoAttached(Map<String, dynamic> json) {
    _bloc.add(TaskDetailPhotoAttached(TaskPhoto.fromJson(json)));
  }

  Future<void> _openReassignDialog(Task task) async {
    final controller = TextEditingController(text: task.assignedToUserId ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reassign task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Assignee user ID',
            hintText: 'Leave blank to unassign',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    _bloc.add(TaskDetailAssigneeChanged(result.isEmpty ? null : result));
  }

  List<TaskStatus> _availableStatuses(TaskStatus current) {
    if (widget.canApprove) return TaskStatus.values;
    return [
      for (final status in TaskStatus.values)
        if (!_approverOnlyStatuses.contains(status) || status == current) status,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Task detail'),
          actions: [
            BlocBuilder<TaskDetailBloc, TaskDetailState>(
              builder: (context, state) {
                final task = state.task;
                if (!widget.canReassign || task == null) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  tooltip: 'Reassign',
                  onPressed: state.isUpdatingTask ? null : () => _openReassignDialog(task),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<TaskDetailBloc, TaskDetailState>(
          listener: (context, state) {
            if (state.actionErrorMessage != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.actionErrorMessage!)));
            }
          },
          builder: (context, state) {
            final task = state.task;
            if (task == null) {
              if (state.errorMessage != null) {
                return Center(child: Text(state.errorMessage!));
              }
              return const LoadingView();
            }

            final detail = RefreshIndicator(
              onRefresh: () async => _bloc.add(const TaskDetailRefreshRequested()),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _buildHeader(context, task),
                  const SizedBox(height: AppSpacing.md),
                  _buildStatusControl(context, task, state.isUpdatingTask),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPriority(context, task),
                  const Divider(height: AppSpacing.xl),
                  Text('Comments', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (state.comments.isEmpty) const Text('No comments yet.'),
                  for (final comment in state.comments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(comment.body),
                      subtitle: Text(_formatDateTime(comment.createdAt)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(hintText: 'Add a comment'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: state.isSubmittingComment ? null : _submitComment,
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xl),
                  Text('Photos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  PhotoPickerField(
                    entityType: UploadEntityType.task,
                    uploadRepository: getIt(),
                    attachPath: '/tasks/${widget.taskId}/photos',
                    targetKind: 'task',
                    targetId: widget.taskId,
                    initialAttachments: [
                      for (final photo in state.photos)
                        PhotoAttachment(photoUrl: photo.photoUrl, caption: photo.caption),
                    ],
                    onAttached: _onPhotoAttached,
                  ),
                ],
              ),
            );

            return ResponsiveScaffold(
              compact: (context) => detail,
              expanded: (context) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxDetailWidth),
                  child: detail,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
        if (task.description != null && task.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(task.description!),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              'Created ${_formatDateTime(task.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (task.dueDate != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Due ${_formatDateTime(task.dueDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (task.isOverdue) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatusControl(BuildContext context, Task task, bool isMutating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<TaskStatus>(
          value: task.status,
          items: [
            for (final status in _availableStatuses(task.status))
              DropdownMenuItem(
                value: status,
                child: Text(status.label, style: TextStyle(color: status.color)),
              ),
          ],
          onChanged: isMutating
              ? null
              : (value) {
                  if (value == null || value == task.status) return;
                  _bloc.add(TaskDetailStatusChanged(value));
                },
        ),
      ],
    );
  }

  Widget _buildPriority(BuildContext context, Task task) {
    return Row(
      children: [
        Text('Priority: ', style: Theme.of(context).textTheme.bodyMedium),
        Chip(
          label: Text(task.priority.label),
          backgroundColor: task.priority.color.withValues(alpha: 0.15),
          labelStyle: TextStyle(color: task.priority.color),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
