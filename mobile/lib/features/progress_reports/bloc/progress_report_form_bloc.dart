import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/offline/offline_queue_repository.dart';

import '../data/progress_report_models.dart';
import '../data/progress_report_repository.dart';
import 'progress_report_form_event.dart';
import 'progress_report_form_state.dart';

/// Manages the in-progress "new progress report" form: the dynamic list of
/// stage entries, and submission of the whole report.
class ProgressReportFormBloc extends Bloc<ProgressReportFormEvent, ProgressReportFormState> {
  ProgressReportFormBloc(this._repository, {OfflineQueueRepository? queueRepository})
    : _queueRepository = queueRepository ?? OfflineQueueRepository(),
      super(const ProgressReportFormState()) {
    on<StageEntryAdded>(_onStageEntryAdded);
    on<StageEntryRemoved>(_onStageEntryRemoved);
    on<StageEntryChanged>(_onStageEntryChanged);
    on<ReportSubmitted>(_onReportSubmitted);
  }

  final ProgressReportRepository _repository;
  final OfflineQueueRepository _queueRepository;

  void _onStageEntryAdded(StageEntryAdded event, Emitter<ProgressReportFormState> emit) {
    emit(
      state.copyWith(
        stageEntries: [...state.stageEntries, const StageEntry(stageName: '', progressPercent: 0)],
      ),
    );
  }

  void _onStageEntryRemoved(StageEntryRemoved event, Emitter<ProgressReportFormState> emit) {
    final updated = List.of(state.stageEntries)..removeAt(event.index);
    emit(state.copyWith(stageEntries: updated));
  }

  void _onStageEntryChanged(StageEntryChanged event, Emitter<ProgressReportFormState> emit) {
    final updated = List.of(state.stageEntries);
    updated[event.index] = event.updated;
    emit(state.copyWith(stageEntries: updated));
  }

  Future<void> _onReportSubmitted(
    ReportSubmitted event,
    Emitter<ProgressReportFormState> emit,
  ) async {
    emit(state.copyWith(status: ProgressReportFormStatus.submitting, errorMessage: null));
    // Rows the user never filled in (still blank stage name) are dropped
    // rather than sent — the backend requires a non-empty `stage_name`,
    // and the form always starts with one blank row by default. Declared
    // outside the `try` so the network-failure branch below can also use it
    // when building the queued-submission payload.
    final entriesToSubmit = state.stageEntries.where((e) => e.stageName.trim().isNotEmpty).toList();
    try {
      final report = await _repository.create(
        projectId: event.projectId,
        reportDate: event.reportDate,
        summary: event.summary,
        overallProgressPercent: event.overallProgressPercent,
        stageEntries: entriesToSubmit,
      );
      emit(
        state.copyWith(
          status: ProgressReportFormStatus.submitted,
          createdReportId: report.id,
        ),
      );
    } on ApiException catch (e) {
      if (e.errorCode == 'network_error') {
        await _queueRepository.enqueueSubmission(
          kind: 'progress_report',
          jsonPayload: jsonEncode({
            'project_id': event.projectId,
            'report_date': event.reportDate.toIso8601String(),
            'summary': event.summary,
            'overall_progress_percent': event.overallProgressPercent,
            'stage_entries': entriesToSubmit.map((e) => e.toJson()).toList(),
          }),
        );
        emit(state.copyWith(status: ProgressReportFormStatus.offlineQueued));
        return;
      }
      emit(state.copyWith(status: ProgressReportFormStatus.failure, errorMessage: e.message));
    }
  }
}
