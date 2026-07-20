import 'dart:async';
import 'dart:convert';

import '../di/injection.dart';
import '../network/api_client.dart';
import 'connectivity_gate.dart';
import 'offline_database.dart';
import 'offline_queue_repository.dart';

import '../../features/progress_reports/data/progress_report_models.dart';
import '../../features/progress_reports/data/progress_report_repository.dart';
import '../../features/tasks/data/task_models.dart';
import '../../features/tasks/data/task_repository.dart';

/// `queued_submissions.kind` values this service knows how to replay. Kept
/// as constants so the enqueueing side (`TaskFormBloc`, `ProgressReportFormBloc`)
/// and this replay side never drift on the literal string.
const String submissionKindTaskStatus = 'task_status';
const String submissionKindProgressReport = 'progress_report';

/// Watches connectivity and, on every offline→online transition (and once at
/// startup if already online), drains `queued_submissions` — replaying each
/// row through the repository method its `kind` belongs to.
///
/// Started once from `main.dart` after DI setup. Builds its own
/// [TaskRepository]/[ProgressReportRepository] from the always-registered
/// [ApiClient] rather than resolving them through `getIt`, since the
/// tasks/progress-reports feature modules may not have registered their own
/// DI yet at the point this service starts.
class SubmissionRetryService {
  SubmissionRetryService({
    TaskRepository? taskRepository,
    ProgressReportRepository? progressReportRepository,
    OfflineQueueRepository? queueRepository,
    ConnectivityGate? connectivityGate,
  }) : _taskRepository = taskRepository ?? TaskRepository(getIt<ApiClient>()),
       _progressReportRepository =
           progressReportRepository ?? ProgressReportRepository(getIt<ApiClient>()),
       _queueRepository = queueRepository ?? OfflineQueueRepository(),
       _connectivityGate = connectivityGate ?? ConnectivityGate();

  final TaskRepository _taskRepository;
  final ProgressReportRepository _progressReportRepository;
  final OfflineQueueRepository _queueRepository;
  final ConnectivityGate _connectivityGate;

  StreamSubscription<bool>? _subscription;
  bool _lastKnownOnline = false;
  bool _isDraining = false;

  /// Subscribes to connectivity changes and, if already online right now,
  /// kicks off an immediate drain (covers submissions queued in a previous
  /// app session that would otherwise wait for the next observed
  /// offline→online flap, which may never come).
  Future<void> start() async {
    _subscription = _connectivityGate.onlineStatus.listen(_onConnectivityChanged);
    _lastKnownOnline = await _connectivityGate.isOnline();
    if (_lastKnownOnline) unawaited(_drain());
  }

  void dispose() {
    unawaited(_subscription?.cancel());
  }

  Future<void> _onConnectivityChanged(bool isOnline) async {
    final wasOffline = !_lastKnownOnline;
    _lastKnownOnline = isOnline;
    if (isOnline && wasOffline) {
      await _drain();
    }
  }

  Future<void> _drain() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      final rows = await _queueRepository.pendingSubmissions();
      for (final row in rows) {
        final id = row['id'] as int;
        try {
          final kind = row['kind'] as String;
          final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          switch (kind) {
            case submissionKindTaskStatus:
              await _replayTask(payload);
              break;
            case submissionKindProgressReport:
              await _replayProgressReport(payload);
              break;
            default:
              // Unknown kind — nothing this build of the app knows how to
              // replay; mark it failed below rather than retrying forever.
              throw StateError('Unknown queued submission kind: $kind');
          }
          await _queueRepository.markSent(queuedSubmissionsTable, id);
        } on Exception {
          await _queueRepository.markFailed(queuedSubmissionsTable, id);
        }
      }
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _replayTask(Map<String, dynamic> payload) {
    return _taskRepository.create(
      projectId: payload['project_id'] as String,
      title: payload['title'] as String,
      description: payload['description'] as String?,
      priority: TaskPriority.fromWire(payload['priority'] as String),
      assignedToUserId: payload['assigned_to_user_id'] as String?,
      dueDate: payload['due_date'] == null
          ? null
          : DateTime.parse(payload['due_date'] as String),
    );
  }

  Future<void> _replayProgressReport(Map<String, dynamic> payload) {
    final stageEntriesJson = payload['stage_entries'] as List<dynamic>? ?? const [];
    return _progressReportRepository.create(
      projectId: payload['project_id'] as String,
      reportDate: DateTime.parse(payload['report_date'] as String),
      summary: payload['summary'] as String?,
      overallProgressPercent: payload['overall_progress_percent'] as int?,
      stageEntries: [
        for (final entry in stageEntriesJson)
          StageEntry(
            stageName: (entry as Map<String, dynamic>)['stage_name'] as String,
            progressPercent: entry['progress_percent'] as int,
            notes: entry['notes'] as String?,
          ),
      ],
    );
  }
}
