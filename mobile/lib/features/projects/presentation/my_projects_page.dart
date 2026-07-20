import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../bloc/my_projects_bloc.dart';
import '../bloc/my_projects_event.dart';
import '../bloc/my_projects_state.dart';
import 'project_map_page.dart';
import 'widgets/project_status_chip.dart';

/// "My Projects" — the projects the current user is actively assigned to
/// (`/assignments/me`, active assignments only), each paired with the
/// caller's assignment role on it. Driven entirely by [MyProjectsBloc]; this
/// page never calls the repository directly.
class MyProjectsPage extends StatelessWidget {
  const MyProjectsPage({super.key, this.canEditProjects = false});

  /// Forwarded to [ProjectMapPage] so its "edit boundary" action only shows
  /// when the caller holds `Permission.projectUpdate` — in practice this is
  /// usually false for the assignment-scoped roles (Site Engineer,
  /// Employee) this page targets, but the caller decides, not this widget.
  final bool canEditProjects;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<MyProjectsBloc>()..add(const MyProjectsRequested()),
      child: _MyProjectsView(canEditProjects: canEditProjects),
    );
  }
}

class _MyProjectsView extends StatelessWidget {
  const _MyProjectsView({required this.canEditProjects});

  final bool canEditProjects;

  void _openProject(BuildContext context, MyProjectItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectMapPage(
          focusedProjectId: item.project.id,
          canEdit: canEditProjects,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Projects')),
      body: BlocBuilder<MyProjectsBloc, MyProjectsState>(
        builder: (context, state) {
          if (state.isLoading && state.items.isEmpty) {
            return const LoadingView();
          }
          if (state.error != null && state.items.isEmpty) {
            return ErrorView(
              message: state.error!,
              onRetry: () => context.read<MyProjectsBloc>().add(
                const MyProjectsRequested(),
              ),
            );
          }
          if (state.items.isEmpty) {
            return const Center(
              child: Text('You have no active project assignments.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => context.read<MyProjectsBloc>().add(
              const MyProjectsRequested(),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _MyProjectTile(
                  item: item,
                  onTap: () => _openProject(context, item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MyProjectTile extends StatelessWidget {
  const _MyProjectTile({required this.item, required this.onTap});

  final MyProjectItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    final assignment = item.assignment;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                ProjectStatusChip(status: project.status),
                const SizedBox(width: AppSpacing.sm),
                Chip(
                  label: Text(_titleCase(assignment.role.value)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Assigned since ${DateFormat.yMMMd().format(assignment.startedAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// `project_engineer` -> `Project Engineer`. There is no `label` field on
/// `AssignmentRole` (unlike the status enums), so this is a generic
/// transform rather than a hardcoded per-value lookup.
String _titleCase(String snakeCase) => snakeCase
    .split('_')
    .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
