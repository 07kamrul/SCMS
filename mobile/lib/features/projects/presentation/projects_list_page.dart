import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../bloc/projects_list_bloc.dart';
import '../bloc/projects_list_event.dart';
import '../bloc/projects_list_state.dart';
import '../data/project_models.dart';
import 'project_form_page.dart';
import 'project_map_page.dart';
import 'widgets/project_status_chip.dart';

/// Status-colored list of every project the caller can see (`/projects`,
/// filtered by status), with pull-to-refresh, tap-through to
/// [ProjectMapPage] focused on that project, and a create FAB.
///
/// Capability flags are plain booleans rather than a permission-checking
/// service so this widget stays independently testable — the caller (router
/// / app shell) decides what the current user is allowed to do, following
/// the same convention as `features/team/presentation/team_list_page.dart`.
class ProjectsListPage extends StatelessWidget {
  const ProjectsListPage({
    super.key,
    this.canCreate = false,
    this.canEditProjects = false,
  });

  /// Gates the "create project" FAB — mirrors `Permission.projectCreate`.
  final bool canCreate;

  /// Forwarded to [ProjectMapPage] so its "edit boundary" action is only
  /// offered when the caller holds `Permission.projectUpdate`.
  final bool canEditProjects;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<ProjectsListBloc>()..add(const ProjectsListRequested()),
      child: _ProjectsListView(
        canCreate: canCreate,
        canEditProjects: canEditProjects,
      ),
    );
  }
}

class _ProjectsListView extends StatefulWidget {
  const _ProjectsListView({
    required this.canCreate,
    required this.canEditProjects,
  });

  final bool canCreate;
  final bool canEditProjects;

  @override
  State<_ProjectsListView> createState() => _ProjectsListViewState();
}

class _ProjectsListViewState extends State<_ProjectsListView> {
  ProjectStatus? _statusFilter;

  void _requestList() {
    context.read<ProjectsListBloc>().add(
      ProjectsListRequested(status: _statusFilter),
    );
  }

  void _openProject(Project project) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectMapPage(
              focusedProjectId: project.id,
              canEdit: widget.canEditProjects,
            ),
          ),
        )
        .then((_) {
          if (context.mounted) _requestList();
        });
  }

  Future<void> _openCreateForm() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProjectFormPage()));
    if (context.mounted) _requestList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: Column(
        children: [
          _StatusFilterRow(
            selected: _statusFilter,
            onChanged: (status) {
              setState(() => _statusFilter = status);
              _requestList();
            },
          ),
          Expanded(
            child: BlocBuilder<ProjectsListBloc, ProjectsListState>(
              builder: (context, state) {
                if (state.isLoading && state.projects.isEmpty) {
                  return const LoadingView();
                }
                if (state.error != null && state.projects.isEmpty) {
                  return ErrorView(
                    message: state.error!,
                    onRetry: _requestList,
                  );
                }
                if (state.projects.isEmpty) {
                  return const Center(child: Text('No projects found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _requestList(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: state.projects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final project = state.projects[index];
                      return _ProjectListTile(
                        project: project,
                        onTap: () => _openProject(project),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.canCreate
          ? FloatingActionButton(
              onPressed: _openCreateForm,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.selected, required this.onChanged});

  final ProjectStatus? selected;
  final ValueChanged<ProjectStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DropdownButton<ProjectStatus?>(
          value: selected,
          hint: const Text('All statuses'),
          items: [
            const DropdownMenuItem<ProjectStatus?>(
              value: null,
              child: Text('All statuses'),
            ),
            for (final status in ProjectStatus.values)
              DropdownMenuItem<ProjectStatus?>(
                value: status,
                child: Text(status.label),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ProjectListTile extends StatelessWidget {
  const _ProjectListTile({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            if (project.description != null &&
                project.description!.isNotEmpty)
              Text(
                project.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                ProjectStatusChip(status: project.status),
                const SizedBox(width: AppSpacing.sm),
                Text('${project.progressPercent}%'),
                const Spacer(),
                if (project.boundary == null)
                  const Tooltip(
                    message: 'No boundary drawn yet',
                    child: Icon(Icons.location_off_outlined, size: 16),
                  ),
              ],
            ),
          ],
        ),
        isThreeLine:
            project.description != null && project.description!.isNotEmpty,
      ),
    );
  }
}

