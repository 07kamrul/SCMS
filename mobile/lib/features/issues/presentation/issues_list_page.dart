import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/error_view.dart';
import 'package:mobile/shared/widgets/loading_view.dart';

import '../bloc/issue_form_state.dart' show IssueAssignee;
import '../bloc/issues_list_bloc.dart';
import '../bloc/issues_list_event.dart';
import '../bloc/issues_list_state.dart';
import '../data/issue_models.dart';
import 'issue_detail_page.dart';
import 'issue_form_page.dart';

/// Issues list for a project: filter chips for status/priority/category,
/// an infinite-scrolling list of colored status+priority chips per issue,
/// and (when [canCreate]) a FAB to report a new one.
class IssuesListPage extends StatefulWidget {
  const IssuesListPage({
    super.key,
    this.projectId,
    this.canCreate = false,
    this.canUpdateIssues = false,
    this.canUploadPhoto = false,
    this.assignableUsers = const [],
  });

  final String? projectId;
  final bool canCreate;
  final bool canUpdateIssues;
  final bool canUploadPhoto;
  final List<IssueAssignee> assignableUsers;

  @override
  State<IssuesListPage> createState() => _IssuesListPageState();
}

class _IssuesListPageState extends State<IssuesListPage> {
  late final IssuesListBloc _bloc;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bloc = getIt<IssuesListBloc>()
      ..add(IssuesListStarted(projectId: widget.projectId));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _onScroll() {
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _bloc.add(const IssuesListNextPageRequested());
    }
  }

  void _openIssue(String issueId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IssueDetailPage(
          issueId: issueId,
          canUpdate: widget.canUpdateIssues,
          canUploadPhoto: widget.canUploadPhoto,
          assignableUsers: widget.assignableUsers,
        ),
      ),
    );
  }

  void _openCreateForm(IssuesListState state) {
    final projectId = widget.projectId;
    if (projectId == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<bool>(
            builder: (_) => IssueFormPage(
              projectId: projectId,
              assignableUsers: widget.assignableUsers,
            ),
          ),
        )
        .then((created) {
          if (created == true) {
            _bloc.add(const IssuesListRefreshed());
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Issues')),
        body: BlocBuilder<IssuesListBloc, IssuesListState>(
          builder: (context, state) {
            return Column(
              children: [
                _buildFilters(context, state),
                Expanded(child: _buildList(context, state)),
              ],
            );
          },
        ),
        floatingActionButton: widget.canCreate
            ? BlocBuilder<IssuesListBloc, IssuesListState>(
                builder: (context, state) => FloatingActionButton(
                  onPressed: () => _openCreateForm(state),
                  child: const Icon(Icons.add),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildFilters(BuildContext context, IssuesListState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chipRow<IssueStatus>(
            values: IssueStatus.values,
            selected: state.statusFilter,
            labelOf: (v) => v.label,
            colorOf: (v) => v.color,
            onSelected: (value) => _bloc.add(
              IssuesListFilterChanged(
                status: value,
                priority: state.priorityFilter,
                category: state.categoryFilter,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _chipRow<IssuePriority>(
            values: IssuePriority.values,
            selected: state.priorityFilter,
            labelOf: (v) => v.label,
            colorOf: (v) => v.color,
            onSelected: (value) => _bloc.add(
              IssuesListFilterChanged(
                status: state.statusFilter,
                priority: value,
                category: state.categoryFilter,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _chipRow<IssueCategory>(
            values: IssueCategory.values,
            selected: state.categoryFilter,
            labelOf: (v) => v.label,
            colorOf: (_) => null,
            onSelected: (value) => _bloc.add(
              IssuesListFilterChanged(
                status: state.statusFilter,
                priority: state.priorityFilter,
                category: value,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow<T>({
    required List<T> values,
    required T? selected,
    required String Function(T) labelOf,
    required Color? Function(T) colorOf,
    required ValueChanged<T?> onSelected,
  }) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(labelOf(value)),
                selected: selected == value,
                selectedColor: colorOf(value)?.withValues(alpha: 0.2),
                onSelected: (isSelected) => onSelected(isSelected ? value : null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, IssuesListState state) {
    if (state.status == IssuesListStatus.loading && state.issues.isEmpty) {
      return const LoadingView();
    }
    if (state.status == IssuesListStatus.failure && state.issues.isEmpty) {
      return ErrorView(
        message: state.errorMessage ?? 'Could not load issues.',
        onRetry: () => _bloc.add(const IssuesListRefreshed()),
      );
    }
    if (state.issues.isEmpty) {
      return const Center(child: Text('No issues found.'));
    }
    return RefreshIndicator(
      onRefresh: () async => _bloc.add(const IssuesListRefreshed()),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.issues.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.issues.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final issue = state.issues[index];
          return ListTile(
            title: Text(issue.title),
            subtitle: Text(issue.category.label),
            trailing: Wrap(
              spacing: AppSpacing.xs,
              children: [
                Chip(
                  label: Text(issue.status.label),
                  backgroundColor: issue.status.color.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: issue.status.color),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(issue.priority.label),
                  backgroundColor: issue.priority.color.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: issue.priority.color),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            onTap: () => _openIssue(issue.id),
          );
        },
      ),
    );
  }
}
