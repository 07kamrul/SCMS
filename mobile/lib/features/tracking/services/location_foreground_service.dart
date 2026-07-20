import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/offline/offline_database.dart';
import 'package:mobile/core/offline/offline_queue_repository.dart';
import 'package:mobile/core/storage/secure_token_storage.dart';

import '../data/location_repository.dart';

/// Caps how many queued fixes a single reporting tick will resend, so a long
/// offline stretch can't make one tick run long enough to blow past the next
/// repeat interval — the remainder simply drains further on later ticks.
const int _maxLocationsPerDrainTick = 50;

/// Reasonable battery/accuracy tradeoff for periodic background reporting.
/// Adjustable — lower it for fresher geofence status at the cost of battery,
/// raise it to conserve battery at the cost of staleness (the backend's
/// `offline_after_minutes` setting determines how stale is too stale).
const int _repeatIntervalMs = 60000;

const String _notificationChannelId = 'scfms_location_tracking';
const String _notificationChannelName = 'Location sharing';

/// Requests the permissions the foreground location service needs:
/// - Location: tries `Permission.locationAlways` first (required for
///   reporting while backgrounded); falls back to `Permission.locationWhenInUse`
///   if the user declines "Allow all the time" — tracking will then only
///   report while the app is in the foreground, which the caller should
///   surface to the user.
/// - Notifications (Android 13+): required to show the persistent tracking
///   notification at all; the foreground service can still start without it
///   on Android 13+, but the user loses the visible indicator, so we ask.
///
/// Returns `true` if at least one location permission tier was granted.
/// If permanently denied, opens the app settings page so the user can grant
/// it manually, per `permission_handler` guidance.
Future<bool> ensureLocationTrackingPermissions() async {
  var locationAlways = await Permission.locationAlways.status;
  if (!locationAlways.isGranted) {
    locationAlways = await Permission.locationAlways.request();
  }

  var hasLocationPermission = locationAlways.isGranted;
  var isPermanentlyDenied = locationAlways.isPermanentlyDenied;

  if (!hasLocationPermission) {
    var whenInUse = await Permission.locationWhenInUse.status;
    if (!whenInUse.isGranted) {
      whenInUse = await Permission.locationWhenInUse.request();
    }
    hasLocationPermission = whenInUse.isGranted;
    isPermanentlyDenied = isPermanentlyDenied || whenInUse.isPermanentlyDenied;
  }

  // Android 13+ only; a no-op status on older Android and on platforms
  // where the plugin has nothing to check.
  final notificationPermission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  if (!hasLocationPermission && isPermanentlyDenied) {
    await openAppSettings();
  }

  return hasLocationPermission;
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: _notificationChannelId,
      channelName: _notificationChannelName,
      channelDescription:
          'Shows while SCFMS is sharing your location with your company.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(_repeatIntervalMs),
      autoRunOnBoot: false,
      allowWakeLock: true,
    ),
  );
}

/// Requests permissions (if not already granted) and starts the persistent
/// foreground service that periodically reports this device's location.
/// Shows an ongoing, non-dismissible notification titled "SCFMS is sharing
/// your location" for as long as the service runs — this is the OS-level
/// tracking indicator; the consent page also shows an in-app banner while
/// active, per the PRD's "always-visible tracking indicator" requirement.
Future<bool> startLocationTracking() async {
  final hasPermission = await ensureLocationTrackingPermissions();
  if (!hasPermission) return false;

  _initForegroundTask();

  if (await FlutterForegroundTask.isRunningService) {
    final result = await FlutterForegroundTask.restartService();
    return result is ServiceRequestSuccess;
  }

  final result = await FlutterForegroundTask.startService(
    notificationTitle: 'SCFMS is sharing your location',
    notificationText:
        'Your position is being shared with your company while you work.',
    callback: startLocationTrackingCallback,
  );
  return result is ServiceRequestSuccess;
}

/// Stops the foreground service and its persistent notification.
Future<void> stopLocationTracking() async {
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.stopService();
  }
}

/// Entry point run by the platform to bind [LocationTrackingTaskHandler] to
/// the foreground service. Must be a top-level (or static) function annotated
/// `@pragma('vm:entry-point')` — `flutter_foreground_task` invokes it in a
/// separate background isolate, so it cannot close over anything from the
/// main isolate (including `getIt`).
@pragma('vm:entry-point')
void startLocationTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTrackingTaskHandler());
}

/// Runs inside the foreground-service isolate. Cannot use `getIt` — that
/// container lives in the main isolate and foreground-task callbacks run in
/// a separate isolate with no access to it (a known `flutter_foreground_task`
/// constraint) — so it builds its own minimal `ApiClient` +
/// `SecureTokenStorage` pair instead. `SecureTokenStorage` reads from the
/// platform secure store directly, which is isolate-safe.
class LocationTrackingTaskHandler extends TaskHandler {
  LocationRepository? _repository;
  OfflineQueueRepository? _queueRepository;
  bool _isolateBinaryMessengerReady = false;

  LocationRepository get _locationRepository {
    return _repository ??= LocationRepository(
      ApiClient(
        tokenStorage: SecureTokenStorage(),
        baseUrl: AppConfig.apiBaseUrl,
      ),
    );
  }

  /// `OfflineQueueRepository` is a plain class (no DI), so it's safe to
  /// instantiate directly from this isolate per the handler's own
  /// isolate constraint — `getIt` lives in the main isolate only.
  OfflineQueueRepository get _offlineQueueRepository =>
      _queueRepository ??= OfflineQueueRepository();

  /// `sqflite` (used transitively by [OfflineQueueRepository]) needs
  /// `BackgroundIsolateBinaryMessenger.ensureInitialized` before its first
  /// platform-channel call when running on a raw background isolate that
  /// doesn't already have one set up.
  ///
  /// In practice, `flutter_foreground_task`'s Android implementation runs
  /// this handler inside its own `FlutterEngine` (a genuine root isolate with
  /// its own binding — see the plugin's `ForegroundService.kt`), which is
  /// exactly why the existing `Geolocator.getCurrentPosition()` call below
  /// already works without any such workaround. There is no init-payload
  /// parameter on `onStart`/`onRepeatEvent` to thread a token from the main
  /// isolate through even if one were needed. So this reads
  /// `RootIsolateToken.instance` *locally*, from inside this isolate, which
  /// is the only value that could possibly be valid here, and swallows any
  /// failure (e.g. "already initialized" because this already is a root
  /// isolate with its own binding) — a defensive no-op on the platform this
  /// was verified against, and a safety net should a future plugin version or
  /// iOS code path ever run this callback as a true `Isolate.spawn` isolate.
  void _ensureBinaryMessengerInitialized() {
    if (_isolateBinaryMessengerReady) return;
    _isolateBinaryMessengerReady = true;
    try {
      final token = RootIsolateToken.instance;
      if (token != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      }
    } on Exception {
      // Already initialized, or unsupported in this context — either way,
      // the sqflite calls below will simply succeed or fail on their own
      // merits, and failures there are already handled best-effort.
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _ensureBinaryMessengerInitialized();
    unawaited(_reportCurrentLocation());
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _ensureBinaryMessengerInitialized();
    unawaited(_reportCurrentLocation());
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _reportCurrentLocation() async {
    await _drainPendingLocations();

    Map<String, dynamic>? reportParams;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      reportParams = _paramsFor(
        lat: position.latitude,
        lng: position.longitude,
        accuracyMeters: position.accuracy,
        recordedAt: position.timestamp,
        isMockLocation: position.isMocked,
      );
      await _sendReportFromParams(reportParams);
    } on ApiException catch (e) {
      // Only a network-level failure (no response reached the server) is
      // worth retrying later — a validation/permission-style rejection from
      // the backend would just fail again identically on replay. `params`
      // is always set by the time an ApiException can be thrown here (it
      // only ever comes from `_sendReportFromParams`, called after
      // `reportParams` is built).
      final params = reportParams;
      if (e.errorCode == 'network_error' && params != null) {
        try {
          await _offlineQueueRepository.enqueueLocation(jsonEncode(params));
        } on Exception {
          // Even the local DB write failed — nothing more to do; the next
          // repeat interval simply tries again from scratch.
        }
      }
    } on Exception {
      // Best-effort: a GPS/location-service failure (no fix obtained) has
      // nothing to queue — must never crash the foreground service, the
      // next repeat interval simply tries again.
    }
  }

  /// Resends up to [_maxLocationsPerDrainTick] previously-failed fixes,
  /// oldest first, before this tick's own live fix is taken — so a long
  /// offline stretch drains in FIFO order across ticks instead of the newest
  /// fix always winning the race.
  Future<void> _drainPendingLocations() async {
    try {
      final rows = await _offlineQueueRepository.pendingLocations();
      for (final row in rows.take(_maxLocationsPerDrainTick)) {
        final id = row['id'] as int;
        try {
          final params = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          await _sendReportFromParams(params);
          await _offlineQueueRepository.markSent(queuedLocationsTable, id);
        } on Exception {
          await _offlineQueueRepository.markFailed(queuedLocationsTable, id);
        }
      }
    } on Exception {
      // Best-effort — if even reading the queue fails, fall through to
      // reporting this tick's live fix as usual.
    }
  }

  Map<String, dynamic> _paramsFor({
    required double lat,
    required double lng,
    double? accuracyMeters,
    required DateTime recordedAt,
    bool isMockLocation = false,
  }) {
    return {
      'lat': lat,
      'lng': lng,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'is_mock_location': isMockLocation,
    };
  }

  Future<void> _sendReportFromParams(Map<String, dynamic> params) {
    return _locationRepository.reportLocation(
      lat: (params['lat'] as num).toDouble(),
      lng: (params['lng'] as num).toDouble(),
      accuracyMeters: (params['accuracy_meters'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(params['recorded_at'] as String),
      isMockLocation: params['is_mock_location'] as bool? ?? false,
    );
  }
}
