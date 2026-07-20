import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../consent_storage.dart';
import '../data/location_repository.dart';
import '../services/location_foreground_service.dart';
import 'tracking_event.dart';
import 'tracking_state.dart';

/// Owns the employee-facing side of location tracking: consent (fetch +
/// give-consent), permission requests, starting/stopping the foreground
/// service, and polling the caller's own current [LocationStatus].
///
/// Consent has no backend "check" endpoint (only `POST /locations/consent`,
/// which is idempotent) — so [_consentStorage] is this device's source of
/// truth for whether the gate has already been passed.
class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  TrackingBloc(
    this._locationRepository,
    this._apiClient,
    this._consentStorage,
  ) : super(const TrackingState()) {
    on<TrackingStarted>(_onStarted);
    on<TrackingConsentRequested>(_onConsentRequested);
    on<TrackingStartRequested>(_onStartRequested);
    on<TrackingStopRequested>(_onStopRequested);
    on<TrackingStatusRefreshed>(_onStatusRefreshed);
  }

  /// How often the employee's own status is re-fetched while the tracking
  /// page is open. Independent of `_repeatIntervalMs` in
  /// `location_foreground_service.dart`, which governs the background
  /// reporting cadence, not the foreground UI's read cadence.
  static const _pollInterval = Duration(seconds: 30);

  final LocationRepository _locationRepository;
  final ApiClient _apiClient;
  final LocationConsentStorage _consentStorage;

  Timer? _pollTimer;

  Future<void> _onStarted(
    TrackingStarted event,
    Emitter<TrackingState> emit,
  ) async {
    emit(state.copyWith(loadStatus: TrackingLoadStatus.loading, clearError: true));

    final consentedAt = await _consentStorage.readConsentedAt();
    final isRunning = await FlutterForegroundTask.isRunningService;

    emit(
      state.copyWith(
        hasConsented: consentedAt != null,
        isTrackingActive: isRunning,
        hasLocationPermission: isRunning || state.hasLocationPermission,
      ),
    );

    if (consentedAt == null) {
      emit(state.copyWith(loadStatus: TrackingLoadStatus.ready));
      return;
    }

    await _refreshStatus(emit);
    _startPolling();
  }

  Future<void> _onConsentRequested(
    TrackingConsentRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(state.copyWith(isSubmittingConsent: true, clearError: true));
    try {
      // No repository method exists for this endpoint (the tracking data/
      // layer is owned by a parallel offline-retry effort), so it's called
      // directly here — the same "construct the call inline" approach
      // `LocationTrackingTaskHandler` already uses for its own isolate.
      final envelope = await _apiClient.post<DateTime>(
        '/locations/consent',
        fromData: (json) => DateTime.parse(
          (json as Map<String, dynamic>)['consented_at'] as String,
        ),
      );
      final consentedAt = envelope.data!;
      await _consentStorage.saveConsentedAt(consentedAt);
      emit(state.copyWith(hasConsented: true, isSubmittingConsent: false));
      await _refreshStatus(emit);
      _startPolling();
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmittingConsent: false, errorMessage: e.message));
    }
  }

  Future<void> _onStartRequested(
    TrackingStartRequested event,
    Emitter<TrackingState> emit,
  ) async {
    if (!state.hasConsented) {
      emit(
        state.copyWith(
          errorMessage: 'Give consent before starting location sharing.',
        ),
      );
      return;
    }

    emit(state.copyWith(isTogglingTracking: true, clearError: true));
    final started = await startLocationTracking();
    emit(
      state.copyWith(
        isTogglingTracking: false,
        isTrackingActive: started,
        hasLocationPermission: started || state.hasLocationPermission,
        errorMessage: started
            ? null
            : 'Location permission was not granted — enable it in system '
                  'settings to start sharing your location.',
        clearError: started,
      ),
    );

    if (started) {
      await _refreshStatus(emit);
      _startPolling();
    }
  }

  Future<void> _onStopRequested(
    TrackingStopRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(state.copyWith(isTogglingTracking: true));
    await stopLocationTracking();
    _pollTimer?.cancel();
    _pollTimer = null;
    emit(state.copyWith(isTogglingTracking: false, isTrackingActive: false));
  }

  Future<void> _onStatusRefreshed(
    TrackingStatusRefreshed event,
    Emitter<TrackingState> emit,
  ) => _refreshStatus(emit);

  Future<void> _refreshStatus(Emitter<TrackingState> emit) async {
    try {
      final result = await _locationRepository.myStatus();
      emit(
        state.copyWith(
          loadStatus: TrackingLoadStatus.ready,
          currentStatus: result.status,
          lastPoint: result.point,
          clearLastPoint: result.point == null,
          lastUpdatedAt: DateTime.now(),
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          loadStatus: TrackingLoadStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => add(const TrackingStatusRefreshed()),
    );
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
