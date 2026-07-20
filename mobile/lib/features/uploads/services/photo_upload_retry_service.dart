import 'dart:async';

import '../../../core/di/injection.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/connectivity_gate.dart';
import '../../../core/offline/offline_database.dart';
import '../../../core/offline/offline_queue_repository.dart';
import '../data/upload_repository.dart';

/// Watches connectivity and, on every offline→online transition (and once at
/// startup if already online), drains `queued_photo_uploads` — replaying each
/// row's presign+PUT+attach as one unit via
/// [UploadRepository.replayQueuedUpload].
///
/// Started once from `main.dart` after DI setup, independent of whichever
/// feature blocs/pages happen to be on screen. Deliberately builds its own
/// [UploadRepository] from the always-registered [ApiClient] rather than
/// resolving one through `getIt`, since the tasks/issues/progress-reports
/// feature modules may not have registered their own DI yet at the point
/// this service starts.
class PhotoUploadRetryService {
  PhotoUploadRetryService({
    UploadRepository? uploadRepository,
    OfflineQueueRepository? queueRepository,
    ConnectivityGate? connectivityGate,
  }) : _uploadRepository = uploadRepository ?? UploadRepository(getIt<ApiClient>()),
       _queueRepository = queueRepository ?? OfflineQueueRepository(),
       _connectivityGate = connectivityGate ?? ConnectivityGate();

  final UploadRepository _uploadRepository;
  final OfflineQueueRepository _queueRepository;
  final ConnectivityGate _connectivityGate;

  StreamSubscription<bool>? _subscription;
  bool _lastKnownOnline = false;
  bool _isDraining = false;

  /// Subscribes to connectivity changes and, if already online right now,
  /// kicks off an immediate drain (covers photos queued in a previous app
  /// session that would otherwise wait for the next observed offline→online
  /// flap, which may never come).
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
      final rows = await _queueRepository.pendingPhotoUploads();
      for (final row in rows) {
        final id = row['id'] as int;
        try {
          await _uploadRepository.replayQueuedUpload(
            entityType: UploadEntityType.fromValue(row['entity_type'] as String),
            localFilePath: row['local_file_path'] as String,
            targetKind: row['target_kind'] as String,
            targetId: row['target_id'] as String,
            caption: row['caption'] as String?,
          );
          await _queueRepository.markSent(queuedPhotoUploadsTable, id);
        } on Exception {
          await _queueRepository.markFailed(queuedPhotoUploadsTable, id);
        }
      }
    } finally {
      _isDraining = false;
    }
  }
}
