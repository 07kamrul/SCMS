import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/loading_view.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import '../bloc/assignment_form_bloc.dart';
import '../bloc/assignment_form_event.dart';
import '../bloc/assignment_form_state.dart';
import '../data/team_models.dart';

const double _kMaxFormWidth = 480;

enum _Action { transfer, end }

/// Creates, ends, or transfers a project assignment for one user.
///
/// `existingAssignment == null` assigns [userId] to a project for the first
/// time. A non-null [existingAssignment] is always the user's current
/// (active, unended) assignment — see `UserDetailPage.activeAssignment` —
/// and offers two mutually exclusive actions: end it outright, or transfer
/// to a different project/role. These map to [AssignmentEndSubmitted] and
/// [AssignmentTransferSubmitted] respectively; the bloc always starts a new
/// assignment row rather than editing one in place, so assignment history
/// is preserved.
class AssignmentFormPage extends StatelessWidget {
  const AssignmentFormPage({
    super.key,
    required this.userId,
    this.existingAssignment,
  });

  final String userId;
  final Assignment? existingAssignment;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AssignmentFormBloc>()
        ..add(const AssignmentFormProjectsRequested()),
      child: _AssignmentFormView(
        userId: userId,
        existingAssignment: existingAssignment,
      ),
    );
  }
}

class _AssignmentFormView extends StatefulWidget {
  const _AssignmentFormView({required this.userId, this.existingAssignment});

  final String userId;
  final Assignment? existingAssignment;

  @override
  State<_AssignmentFormView> createState() => _AssignmentFormViewState();
}

class _AssignmentFormViewState extends State<_AssignmentFormView> {
  final _formKey = GlobalKey<FormState>();
  String? _projectId;
  AssignmentRole _role = AssignmentRole.employee;
  _Action _action = _Action.transfer;

  bool get _isExisting => widget.existingAssignment != null;
  bool get _needsProjectPicker => !_isExisting || _action == _Action.transfer;

  void _submit() {
    final existing = widget.existingAssignment;
    if (existing != null && _action == _Action.end) {
      context.read<AssignmentFormBloc>().add(
        AssignmentEndSubmitted(existing.id),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final projectId = _projectId;
    if (projectId == null) return;
    if (existing != null) {
      context.read<AssignmentFormBloc>().add(
        AssignmentTransferSubmitted(
          assignmentId: existing.id,
          newProjectId: projectId,
          role: _role,
        ),
      );
    } else {
      context.read<AssignmentFormBloc>().add(
        AssignmentCreateSubmitted(
          projectId: projectId,
          userId: widget.userId,
          role: _role,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isExisting ? 'Manage assignment' : 'Assign to project'),
      ),
      body: SafeArea(
        child: BlocConsumer<AssignmentFormBloc, AssignmentFormState>(
          listenWhen: (previous, current) =>
              current.status == AssignmentFormStatus.success ||
              (current.status == AssignmentFormStatus.failure &&
                  current.errorMessage != previous.errorMessage),
          listener: (context, state) {
            if (state.status == AssignmentFormStatus.success) {
              Navigator.of(context).pop(state.savedAssignment);
            } else if (state.status == AssignmentFormStatus.failure) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          },
          builder: (context, state) {
            final isInitialLoad =
                state.projects.isEmpty &&
                (state.status == AssignmentFormStatus.initial ||
                    state.status == AssignmentFormStatus.loadingProjects);
            if (isInitialLoad) {
              return const LoadingView();
            }
            if (state.projects.isEmpty &&
                state.status == AssignmentFormStatus.failure) {
              return Center(
                child: Text(state.errorMessage ?? 'Failed to load projects.'),
              );
            }
            final isBusy = state.status == AssignmentFormStatus.submitting;
            final existing = widget.existingAssignment;
            final form = Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (existing != null) ...[
                    Text(
                      'Currently on project ${existing.projectId}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<_Action>(
                      segments: const [
                        ButtonSegment(
                          value: _Action.transfer,
                          label: Text('Transfer'),
                        ),
                        ButtonSegment(
                          value: _Action.end,
                          label: Text('End assignment'),
                        ),
                      ],
                      selected: {_action},
                      onSelectionChanged: (selection) =>
                          setState(() => _action = selection.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_needsProjectPicker) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _projectId,
                      decoration: const InputDecoration(labelText: 'Project'),
                      items: state.projects
                          .map(
                            (project) => DropdownMenuItem(
                              value: project.id,
                              child: Text(project.name),
                            ),
                          )
                          .toList(),
                      onChanged: (projectId) =>
                          setState(() => _projectId = projectId),
                      validator: (value) =>
                          value == null ? 'Select a project' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<AssignmentRole>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: AssignmentRole.values
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role.value),
                            ),
                          )
                          .toList(),
                      onChanged: (role) {
                        if (role != null) setState(() => _role = role);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  FilledButton(
                    onPressed: isBusy ? null : _submit,
                    child: isBusy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            switch ((_isExisting, _action)) {
                              (false, _) => 'Assign',
                              (true, _Action.end) => 'End assignment',
                              (true, _Action.transfer) => 'Transfer',
                            },
                          ),
                  ),
                ],
              ),
            );
            return ResponsiveScaffold(
              compact: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: form,
              ),
              expanded: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
                    child: form,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
