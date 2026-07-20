import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/uploads/data/upload_repository.dart';
import 'package:mobile/features/uploads/presentation/photo_picker_field.dart';
import 'package:mobile/shared/widgets/loading_view.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import '../bloc/issue_detail_bloc.dart';
import '../bloc/issue_detail_event.dart';
import '../bloc/issue_detail_state.dart';
import '../bloc/issue_form_state.dart' show IssueAssignee;
import '../data/issue_models.dart';

/// Full issue detail: info, status/priority/category/assignee controls
/// (when [canUpdate]), a status-history timeline, comments, and photos.
class IssueDetailPage extends StatefulWidget {
  const IssueDetailPage({
    super.key,
    required this.issueId,
    this.canUpdate = false,
    this.canUploadPhoto = false,
    this.assignableUsers = const [],
  });

  final String issueId;
  final bool canUpdate;
  final bool canUploadPhoto;
  final List<IssueAssignee> assignableUsers;

  @override
  State<IssueDetailPage> createState() => _IssueDetailPageState();
}

class _IssueDetailPageState extends State<IssueDetailPage> {
  late final IssueDetailBloc _bloc;
  final _commentController = TextEditingController();
  final _reasonController = TextEditingController();
  IssueStatus? _pendingStatus;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<IssueDetailBloc>()..add(IssueDetailStarted(widget.issueId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _reasonController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _submitComment() {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    _bloc.add(IssueDetailCommentAdded(body));
    _commentController.clear();
  }

  void _confirmStatusChange() {
    final newStatus = _pendingStatus;
    if (newStatus == null) return;
    final note = _reasonController.text.trim();
    _bloc.add(IssueDetailStatusChanged(newStatus, note: note.isEmpty ? null : note));
    setState(() {
      _pendingStatus = null;
      _reasonController.clear();
    });
  }

  void _onPhotoAttached(Map<String, dynamic> json) {
    _bloc.add(IssueDetailPhotoAttached(IssuePhoto.fromJson(json)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Issue detail')),
        body: BlocConsumer<IssueDetailBloc, IssueDetailState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          },
          builder: (context, state) {
            final issue = state.issue;
            if (issue == null) {
              if (state.status == IssueDetailStatus.failure) {
                return Center(
                  child: Text(state.errorMessage ?? 'Could not load this issue.'),
                );
              }
              return const LoadingView();
            }

            final detail = RefreshIndicator(
              onRefresh: () async => _bloc.add(const IssueDetailRefreshed()),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _buildHeader(context, issue),
                  const SizedBox(height: AppSpacing.md),
                  _buildStatusControl(context, issue, state.isMutating),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPriorityAndCategory(context, issue, state.isMutating),
                  if (widget.canUpdate && widget.assignableUsers.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildAssigneeControl(context, issue, state.isMutating),
                  ],
                  const Divider(height: AppSpacing.xl),
                  Text('History', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (state.history.isEmpty) const Text('No status changes yet.'),
                  for (final entry in state.history.reversed) _historyTile(entry),
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
                          decoration: const InputDecoration(
                            hintText: 'Add a comment',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: state.isMutating ? null : _submitComment,
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xl),
                  Text('Photos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (widget.canUploadPhoto)
                    PhotoPickerField(
                      entityType: UploadEntityType.issue,
                      uploadRepository: getIt(),
                      attachPath: '/issues/${widget.issueId}/photos',
                      targetKind: 'issue',
                      targetId: widget.issueId,
                      initialAttachments: [
                        for (final photo in state.photos)
                          PhotoAttachment(photoUrl: photo.photoUrl, caption: photo.caption),
                      ],
                      onAttached: _onPhotoAttached,
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final photo in state.photos)
                          ClipRRect(
                            borderRadius: AppRadius.smAll,
                            child: Image.network(
                              photo.photoUrl,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );

            return ResponsiveScaffold(
              compact: (context) => detail,
              expanded: (context) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: detail,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Issue issue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(issue.title, style: Theme.of(context).textTheme.headlineSmall),
        if (issue.description != null && issue.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(issue.description!),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Reported ${_formatDateTime(issue.createdAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStatusControl(BuildContext context, Issue issue, bool isMutating) {
    if (!widget.canUpdate) {
      return Chip(
        label: Text(issue.status.label),
        backgroundColor: issue.status.color.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: issue.status.color),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<IssueStatus>(
          value: _pendingStatus ?? issue.status,
          items: [
            for (final status in IssueStatus.values)
              DropdownMenuItem(
                value: status,
                child: Text(status.label, style: TextStyle(color: status.color)),
              ),
          ],
          onChanged: isMutating
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _pendingStatus = value == issue.status ? null : value;
                  });
                },
        ),
        if (_pendingStatus != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason for status change (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: isMutating ? null : _confirmStatusChange,
            child: const Text('Update status'),
          ),
        ],
      ],
    );
  }

  Widget _buildPriorityAndCategory(BuildContext context, Issue issue, bool isMutating) {
    if (!widget.canUpdate) {
      return Wrap(
        spacing: AppSpacing.sm,
        children: [
          Chip(
            label: Text(issue.priority.label),
            backgroundColor: issue.priority.color.withValues(alpha: 0.15),
            labelStyle: TextStyle(color: issue.priority.color),
          ),
          Chip(label: Text(issue.category.label)),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<IssuePriority>(
            initialValue: issue.priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: [
              for (final priority in IssuePriority.values)
                DropdownMenuItem(
                  value: priority,
                  child: Text(priority.label, style: TextStyle(color: priority.color)),
                ),
            ],
            onChanged: isMutating
                ? null
                : (value) {
                    if (value != null) {
                      _bloc.add(IssueDetailPriorityChanged(value));
                    }
                  },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButtonFormField<IssueCategory>(
            initialValue: issue.category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in IssueCategory.values)
                DropdownMenuItem(value: category, child: Text(category.label)),
            ],
            onChanged: isMutating
                ? null
                : (value) {
                    if (value != null) {
                      _bloc.add(IssueDetailCategoryChanged(value));
                    }
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildAssigneeControl(BuildContext context, Issue issue, bool isMutating) {
    return DropdownButtonFormField<String?>(
      initialValue: issue.assignedToUserId,
      decoration: const InputDecoration(labelText: 'Assigned to'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Unassigned')),
        for (final assignee in widget.assignableUsers)
          DropdownMenuItem(value: assignee.id, child: Text(assignee.displayName)),
      ],
      onChanged: isMutating
          ? null
          : (value) => _bloc.add(IssueDetailAssigneeChanged(value)),
    );
  }

  Widget _historyTile(IssueStatusHistoryEntry entry) {
    final from = entry.fromStatus?.label ?? 'New';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$from → ${entry.toStatus.label}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.note != null && entry.note!.isNotEmpty) Text(entry.note!),
          Text(_formatDateTime(entry.createdAt)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
