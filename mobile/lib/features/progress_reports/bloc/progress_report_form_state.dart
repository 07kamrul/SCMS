import 'package:equatable/equatable.dart';

import '../data/progress_report_models.dart';

enum ProgressReportFormStatus {
  editing,
  submitting,
  submitted,

  /// Submission failed with a *network* error — the report has been queued
  /// via `OfflineQueueRepository.enqueueSubmission` (`kind: 'progress_report'`)
  /// and `SubmissionRetryService` will create it for real once connectivity
  /// returns. Unlike [submitted], there is no [ProgressReportFormState.createdReportId]
  /// yet, so the UI can't offer the photo-attach step here.
  offlineQueued,
  failure,
}

/// State for [ProgressReportFormBloc]. Editing fields ([stageEntries]) and
/// submission status coexist in one state (rather than sealed subclasses)
/// because the stage-entry rows stay meaningful/editable while a submit is
/// in flight or has failed.
class ProgressReportFormState extends Equatable {
  const ProgressReportFormState({
    this.stageEntries = const [StageEntry(stageName: '', progressPercent: 0)],
    this.status = ProgressReportFormStatus.editing,
    this.createdReportId,
    this.errorMessage,
  });

  final List<StageEntry> stageEntries;
  final ProgressReportFormStatus status;

  /// Set once [ReportSubmitted] succeeds — the id of the newly-created
  /// report, used to attach photos to it afterwards.
  final String? createdReportId;
  final String? errorMessage;

  ProgressReportFormState copyWith({
    List<StageEntry>? stageEntries,
    ProgressReportFormStatus? status,
    String? createdReportId,
    String? errorMessage,
  }) {
    return ProgressReportFormState(
      stageEntries: stageEntries ?? this.stageEntries,
      status: status ?? this.status,
      createdReportId: createdReportId ?? this.createdReportId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [stageEntries, status, createdReportId, errorMessage];
}
