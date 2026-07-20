import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../bloc/issue_form_bloc.dart';
import '../bloc/issue_form_event.dart';
import '../bloc/issue_form_state.dart';
import '../data/issue_models.dart';

const double _kMaxFormWidth = 560;

/// Create-issue form, scoped to [projectId]. [assignableUsers] is supplied
/// by the caller (typically a project's team roster already loaded by the
/// issues list page) so this feature never has to fetch users itself.
class IssueFormPage extends StatelessWidget {
  const IssueFormPage({
    super.key,
    required this.projectId,
    this.assignableUsers = const [],
  });

  final String projectId;
  final List<IssueAssignee> assignableUsers;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IssueFormBloc>(
      create: (_) => getIt<IssueFormBloc>(),
      child: _IssueFormView(
        projectId: projectId,
        assignableUsers: assignableUsers,
      ),
    );
  }
}

class _IssueFormView extends StatefulWidget {
  const _IssueFormView({
    required this.projectId,
    required this.assignableUsers,
  });

  final String projectId;
  final List<IssueAssignee> assignableUsers;

  @override
  State<_IssueFormView> createState() => _IssueFormViewState();
}

class _IssueFormViewState extends State<_IssueFormView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<IssueFormBloc>().add(IssueFormSubmitted(widget.projectId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report issue')),
      body: BlocConsumer<IssueFormBloc, IssueFormState>(
        listenWhen: (previous, current) => current.status != previous.status,
        listener: (context, state) {
          if (state.status == IssueFormStatus.success) {
            Navigator.of(context).pop(true);
            return;
          }
          if (state.status == IssueFormStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          final form = Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      maxLength: 200,
                      onChanged: (value) => context.read<IssueFormBloc>().add(
                        IssueFormTitleChanged(value),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Title is required'
                          : null,
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLength: 5000,
                      maxLines: 4,
                      onChanged: (value) => context.read<IssueFormBloc>().add(
                        IssueFormDescriptionChanged(value),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<IssueCategory>(
                      initialValue: state.category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final category in IssueCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          context.read<IssueFormBloc>().add(
                            IssueFormCategoryChanged(value),
                          );
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Category is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<IssuePriority>(
                      initialValue: state.priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: [
                        for (final priority in IssuePriority.values)
                          DropdownMenuItem(
                            value: priority,
                            child: Text(priority.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          context.read<IssueFormBloc>().add(
                            IssueFormPriorityChanged(value),
                          );
                        }
                      },
                    ),
                    if (widget.assignableUsers.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String?>(
                        initialValue: state.assignedToUserId,
                        decoration: const InputDecoration(
                          labelText: 'Assign to',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          for (final user in widget.assignableUsers)
                            DropdownMenuItem<String?>(
                              value: user.id,
                              child: Text(user.displayName),
                            ),
                        ],
                        onChanged: (value) => context.read<IssueFormBloc>().add(
                          IssueFormAssigneeChanged(value),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: state.status == IssueFormStatus.submitting
                          ? null
                          : () => _submit(context),
                      child: state.status == IssueFormStatus.submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit issue'),
                    ),
                  ],
                ),
              );
          return ResponsiveScaffold(
            compact: (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: form,
              ),
            ),
            expanded: (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
                    child: form,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
