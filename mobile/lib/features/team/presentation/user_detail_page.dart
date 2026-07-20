import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/loading_view.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import '../../projects/data/project_repository.dart';
import '../data/team_models.dart';
import '../data/team_repository.dart';
import 'assignment_form_page.dart';
import 'team_list_page.dart';

const double _kMaxDetailWidth = 640;

class _DetailData {
  const _DetailData({
    required this.user,
    required this.assignments,
    required this.projectNames,
  });

  final TeamUser user;
  final List<Assignment> assignments;

  /// Project id -> name, so assignment rows can show a readable project
  /// name instead of a raw id. Best-effort: if the picker fetch fails or the
  /// caller lacks project-view permission, falls back to showing the id.
  final Map<String, String> projectNames;

  Assignment? get activeAssignment {
    for (final assignment in assignments) {
      if (assignment.isActive) return assignment;
    }
    return null;
  }
}

/// Shows a single user's profile plus their assignment history
/// (`GET /assignments?user_id=...`), with a button to open [AssignmentFormPage]
/// for this user.
///
/// Talks to [TeamRepository] directly (no dedicated bloc) — this page is a
/// simple read + navigate screen, matching the precedent of other
/// repository-direct pages in this app (e.g. `RegisterCompanyPage`).
class UserDetailPage extends StatefulWidget {
  const UserDetailPage({
    super.key,
    required this.userId,
    required this.canUpdateUser,
    required this.canManageAssignments,
  });

  final String userId;
  final bool canUpdateUser;
  final bool canManageAssignments;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  late Future<_DetailData> _future;
  final _dateFormat = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final repository = getIt<TeamRepository>();
    final user = await repository.getUser(widget.userId);
    final assignmentPage = await repository.listAssignments(
      userId: widget.userId,
    );
    final assignments = [...assignmentPage.assignments]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    var projectNames = <String, String>{};
    try {
      final projects = await getIt<ProjectRepository>().listForMap();
      projectNames = {for (final p in projects) p.id: p.name};
    } on ApiException {
      // Best-effort: assignment rows fall back to showing the raw id.
    }

    return _DetailData(
      user: user,
      assignments: assignments,
      projectNames: projectNames,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openAssignmentForm(
    BuildContext context,
    Assignment? activeAssignment,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssignmentFormPage(
          userId: widget.userId,
          existingAssignment: activeAssignment,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User details')),
      body: SafeArea(
        child: FutureBuilder<_DetailData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              final message = snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Failed to load user.';
              return Center(child: Text(message));
            }
            final data = snapshot.data!;
            final detail = RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _ProfileCard(user: data.user),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Assignments',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.canManageAssignments)
                        TextButton.icon(
                          onPressed: () => _openAssignmentForm(
                            context,
                            data.activeAssignment,
                          ),
                          icon: const Icon(Icons.assignment_ind_outlined),
                          label: Text(
                            data.activeAssignment == null
                                ? 'Assign to project'
                                : 'Manage assignment',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.assignments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text('No assignments yet.'),
                    )
                  else
                    ...data.assignments.map(
                      (assignment) => _AssignmentTile(
                        assignment: assignment,
                        dateFormat: _dateFormat,
                        projectName: data.projectNames[assignment.projectId],
                      ),
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
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final TeamUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [RoleChip(role: user.role), const SizedBox(width: AppSpacing.sm), UserStatusChip(status: user.status)]),
            const SizedBox(height: AppSpacing.sm),
            if (user.jobTitle != null) Text('Job title: ${user.jobTitle}'),
            if (user.email != null) Text('Email: ${user.email}'),
            if (user.phone != null) Text('Phone: ${user.phone}'),
            Text(
              user.isIdentityVerified
                  ? 'Identity verified'
                  : 'Identity not verified',
              style: TextStyle(
                color: user.isIdentityVerified ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.dateFormat,
    this.projectName,
  });

  final Assignment assignment;
  final DateFormat dateFormat;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final period = assignment.endedAt == null
        ? 'Since ${dateFormat.format(assignment.startedAt)}'
        : '${dateFormat.format(assignment.startedAt)} – ${dateFormat.format(assignment.endedAt!)}';
    return Card(
      child: ListTile(
        title: Text(projectName ?? 'Project ${assignment.projectId}'),
        subtitle: Text('${assignment.role.value} · $period'),
        trailing: assignment.isActive
            ? const Chip(
                label: Text('Active', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}
