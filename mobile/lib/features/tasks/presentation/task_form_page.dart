import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../bloc/task_form_bloc.dart';
import '../bloc/task_form_event.dart';
import '../bloc/task_form_state.dart';
import '../data/task_models.dart';

const double _kMaxFormWidth = 560;

/// Create-task form. [assignableUsers] is supplied by the caller (typically
/// the `team` feature resolves this list) so this feature never has to
/// import or fetch users itself.
class TaskFormPage extends StatelessWidget {
  const TaskFormPage({
    super.key,
    required this.projectId,
    this.assignableUsers = const [],
  });

  final String projectId;
  final List<AssignableUser> assignableUsers;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TaskFormBloc>(
      create: (_) => getIt<TaskFormBloc>()
        ..add(
          TaskFormInitialized(
            projectId: projectId,
            assignableUsers: assignableUsers,
          ),
        ),
      child: const _TaskFormView(),
    );
  }
}

class _TaskFormView extends StatefulWidget {
  const _TaskFormView();

  @override
  State<_TaskFormView> createState() => _TaskFormViewState();
}

class _TaskFormViewState extends State<_TaskFormView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null && context.mounted) {
      context.read<TaskFormBloc>().add(TaskFormDueDateChanged(picked));
    }
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<TaskFormBloc>().add(const TaskFormSubmitted());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New task')),
      body: BlocConsumer<TaskFormBloc, TaskFormState>(
        listenWhen: (previous, current) =>
            current.isSuccess != previous.isSuccess ||
            current.isOfflineQueued != previous.isOfflineQueued ||
            current.errorMessage != previous.errorMessage,
        listener: (context, state) {
          if (state.isSuccess) {
            Navigator.of(context).pop(state.createdTask);
            return;
          }
          if (state.isOfflineQueued) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "No connection — this task will be created automatically once you're back online.",
                ),
              ),
            );
            Navigator.of(context).pop();
            return;
          }
          if (state.errorMessage != null) {
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
                      onChanged: (value) => context.read<TaskFormBloc>().add(
                        TaskFormTitleChanged(value),
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
                      onChanged: (value) => context.read<TaskFormBloc>().add(
                        TaskFormDescriptionChanged(value),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<TaskPriority>(
                      initialValue: state.priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: [
                        for (final priority in TaskPriority.values)
                          DropdownMenuItem(
                            value: priority,
                            child: Text(priority.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          context.read<TaskFormBloc>().add(
                            TaskFormPriorityChanged(value),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        state.dueDate == null
                            ? 'No due date'
                            : 'Due ${DateFormat.yMMMd().format(state.dueDate!)}',
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () => _pickDueDate(context, state.dueDate),
                    ),
                    if (state.assignableUsers.isNotEmpty) ...[
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
                          for (final user in state.assignableUsers)
                            DropdownMenuItem<String?>(
                              value: user.id,
                              child: Text(user.name),
                            ),
                        ],
                        onChanged: (value) => context.read<TaskFormBloc>().add(
                          TaskFormAssigneeChanged(value),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: state.isSubmitting ? null : () => _submit(context),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create task'),
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
