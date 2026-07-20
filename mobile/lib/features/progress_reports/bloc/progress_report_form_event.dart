import 'package:equatable/equatable.dart';

import '../data/progress_report_models.dart';

/// Events consumed by [ProgressReportFormBloc].
sealed class ProgressReportFormEvent extends Equatable {
  const ProgressReportFormEvent();

  @override
  List<Object?> get props => [];
}

/// Appends a new blank stage-entry row.
final class StageEntryAdded extends ProgressReportFormEvent {
  const StageEntryAdded();
}

/// Removes the stage-entry row at [index].
final class StageEntryRemoved extends ProgressReportFormEvent {
  const StageEntryRemoved(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// Replaces the stage-entry row at [index] with [updated] (fired on every
/// keystroke/slider change within that row).
final class StageEntryChanged extends ProgressReportFormEvent {
  const StageEntryChanged(this.index, this.updated);

  final int index;
  final StageEntry updated;

  @override
  List<Object?> get props => [index, updated];
}

/// Fired when the user submits the report form. Uses the bloc's current
/// `stageEntries` (blank-named rows are dropped — the backend rejects an
/// empty `stage_name`).
final class ReportSubmitted extends ProgressReportFormEvent {
  const ReportSubmitted({
    required this.projectId,
    required this.reportDate,
    this.summary,
    this.overallProgressPercent,
  });

  final String projectId;
  final DateTime reportDate;
  final String? summary;
  final int? overallProgressPercent;

  @override
  List<Object?> get props => [projectId, reportDate, summary, overallProgressPercent];
}
