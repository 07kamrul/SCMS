import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import '../../uploads/data/upload_repository.dart';
import '../../uploads/presentation/photo_picker_field.dart';
import '../bloc/progress_report_form_bloc.dart';
import '../bloc/progress_report_form_event.dart';
import '../bloc/progress_report_form_state.dart';
import '../data/progress_report_models.dart';

const double _kMaxFormWidth = 640;

/// New-progress-report form: date, summary, optional overall-progress
/// percent, and a dynamic list of free-text stage entries. After a
/// successful submit, transitions in place into a "attach photos" step for
/// the newly-created report.
class ProgressReportFormPage extends StatelessWidget {
  const ProgressReportFormPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProgressReportFormBloc>(),
      child: _ProgressReportFormView(projectId: projectId),
    );
  }
}

class _ProgressReportFormView extends StatefulWidget {
  const _ProgressReportFormView({required this.projectId});

  final String projectId;

  @override
  State<_ProgressReportFormView> createState() => _ProgressReportFormViewState();
}

class _ProgressReportFormViewState extends State<_ProgressReportFormView> {
  final _summaryController = TextEditingController();
  DateTime _reportDate = DateTime.now();
  bool _updateOverallProgress = false;
  double _overallProgressPercent = 0;

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _reportDate = picked);
  }

  void _submit() {
    context.read<ProgressReportFormBloc>().add(
      ReportSubmitted(
        projectId: widget.projectId,
        reportDate: _reportDate,
        summary: _summaryController.text.trim().isEmpty ? null : _summaryController.text.trim(),
        overallProgressPercent: _updateOverallProgress ? _overallProgressPercent.round() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressReportFormBloc, ProgressReportFormState>(
      builder: (context, state) {
        if (state.status == ProgressReportFormStatus.submitted && state.createdReportId != null) {
          return _PhotoAttachStep(reportId: state.createdReportId!);
        }
        if (state.status == ProgressReportFormStatus.offlineQueued) {
          return const _OfflineQueuedStep();
        }
        final isSubmitting = state.status == ProgressReportFormStatus.submitting;
        final form = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Report date'),
                  subtitle: Text(DateFormat.yMMMd().format(_reportDate)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: isSubmitting ? null : _pickDate,
                ),
                TextField(
                  controller: _summaryController,
                  maxLines: 3,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(labelText: 'Summary (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Update overall project progress'),
                  value: _updateOverallProgress,
                  onChanged: isSubmitting
                      ? null
                      : (value) => setState(() => _updateOverallProgress = value),
                ),
                if (_updateOverallProgress) ...[
                  Text('${_overallProgressPercent.round()}%'),
                  Slider(
                    value: _overallProgressPercent,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${_overallProgressPercent.round()}%',
                    onChanged: isSubmitting
                        ? null
                        : (value) => setState(() => _overallProgressPercent = value),
                  ),
                ],
                const Divider(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Stage progress', style: Theme.of(context).textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () => context.read<ProgressReportFormBloc>().add(const StageEntryAdded()),
                      icon: const Icon(Icons.add),
                      label: const Text('Add stage'),
                    ),
                  ],
                ),
                for (var i = 0; i < state.stageEntries.length; i++)
                  _StageEntryRow(
                    key: ValueKey(i),
                    entry: state.stageEntries[i],
                    enabled: !isSubmitting,
                    onChanged: (updated) =>
                        context.read<ProgressReportFormBloc>().add(StageEntryChanged(i, updated)),
                    onRemove: () =>
                        context.read<ProgressReportFormBloc>().add(StageEntryRemoved(i)),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (state.status == ProgressReportFormStatus.failure && state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit report'),
                  ),
                ),
              ],
            );
        return Scaffold(
          appBar: AppBar(title: const Text('New Progress Report')),
          body: ResponsiveScaffold(
            compact: (context) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
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
          ),
        );
      },
    );
  }
}

class _StageEntryRow extends StatefulWidget {
  const _StageEntryRow({
    super.key,
    required this.entry,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final StageEntry entry;
  final bool enabled;
  final ValueChanged<StageEntry> onChanged;
  final VoidCallback onRemove;

  @override
  State<_StageEntryRow> createState() => _StageEntryRowState();
}

class _StageEntryRowState extends State<_StageEntryRow> {
  late final TextEditingController _nameController = TextEditingController(text: widget.entry.stageName);
  late final TextEditingController _notesController = TextEditingController(text: widget.entry.notes ?? '');

  @override
  void didUpdateWidget(covariant _StageEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the controllers in sync when this row's data changes for a
    // reason other than typing in this row itself (e.g. another row above
    // it was removed, shifting this entry into this position).
    if (_nameController.text != widget.entry.stageName) {
      _nameController.text = widget.entry.stageName;
    }
    final notes = widget.entry.notes ?? '';
    if (_notesController.text != notes) {
      _notesController.text = notes;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _emit({String? stageName, int? progressPercent, String? notes}) {
    widget.onChanged(
      StageEntry(
        stageName: stageName ?? widget.entry.stageName,
        progressPercent: progressPercent ?? widget.entry.progressPercent,
        notes: notes ?? widget.entry.notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    enabled: widget.enabled,
                    decoration: const InputDecoration(labelText: 'Stage name'),
                    onChanged: (value) => _emit(stageName: value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.enabled ? widget.onRemove : null,
                  tooltip: 'Remove stage',
                ),
              ],
            ),
            Text('Progress: ${widget.entry.progressPercent}%'),
            Slider(
              value: widget.entry.progressPercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '${widget.entry.progressPercent}%',
              onChanged: widget.enabled ? (value) => _emit(progressPercent: value.round()) : null,
            ),
            TextField(
              controller: _notesController,
              enabled: widget.enabled,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              onChanged: (value) => _emit(notes: value),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the form when submission failed with a network error —
/// the report has been queued locally and `SubmissionRetryService` will
/// create it for real once connectivity returns. There is no server-assigned
/// report id yet, so (unlike [_PhotoAttachStep]) photos can't be attached
/// here; the user can add them later from the report's detail/timeline view
/// once it has synced.
class _OfflineQueuedStep extends StatelessWidget {
  const _OfflineQueuedStep();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Offline')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "No connection right now — this report has been saved on your "
              "device and will be submitted automatically once you're back "
              "online.",
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the form once the report has been created. Lets the
/// user attach photos to the new report via the shared [PhotoPickerField],
/// then finish.
class _PhotoAttachStep extends StatefulWidget {
  const _PhotoAttachStep({required this.reportId});

  final String reportId;

  @override
  State<_PhotoAttachStep> createState() => _PhotoAttachStepState();
}

class _PhotoAttachStepState extends State<_PhotoAttachStep> {
  final _uploadRepository = getIt<UploadRepository>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attach Photos')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report submitted. Optionally attach site photos below.'),
            const SizedBox(height: AppSpacing.md),
            // `PhotoPickerField` itself does presign+PUT+attach as one call
            // and shows its own inline error (including a "will sync later"
            // notice if queued for offline retry) — nothing further needed
            // here.
            PhotoPickerField(
              entityType: UploadEntityType.progress,
              uploadRepository: _uploadRepository,
              attachPath: '/progress-reports/${widget.reportId}/photos',
              targetKind: 'progress_report',
              targetId: widget.reportId,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
