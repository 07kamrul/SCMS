import 'package:equatable/equatable.dart';

import '../data/location_models.dart';

/// Lifecycle of the initial status load. Independent of the consent/tracking
/// flags below, which can each change at any point after [ready].
enum TrackingLoadStatus { initial, loading, ready, failure }

/// State for [TrackingBloc] — the employee's own consent, permission,
/// foreground-service, and current-geofence-status flags. All 10
/// [LocationStatus] values are represented distinctly by [currentStatus]
/// (defaulting to [LocationStatus.unknown] before the first successful
/// fetch), never collapsed.
class TrackingState extends Equatable {
  const TrackingState({
    this.loadStatus = TrackingLoadStatus.initial,
    this.hasConsented = false,
    this.isSubmittingConsent = false,
    this.hasLocationPermission = false,
    this.isTrackingActive = false,
    this.isTogglingTracking = false,
    this.currentStatus = LocationStatus.unknown,
    this.lastPoint,
    this.lastUpdatedAt,
    this.errorMessage,
  });

  final TrackingLoadStatus loadStatus;

  /// Whether this device has locally recorded that the user granted
  /// location-tracking consent (see `consent_storage.dart`).
  final bool hasConsented;
  final bool isSubmittingConsent;

  /// Whether at least one location-permission tier (always or when-in-use)
  /// is currently granted, per the last permission request/check.
  final bool hasLocationPermission;

  /// Whether the persistent foreground service is currently running.
  final bool isTrackingActive;
  final bool isTogglingTracking;

  final LocationStatus currentStatus;
  final LocationPoint? lastPoint;
  final DateTime? lastUpdatedAt;
  final String? errorMessage;

  TrackingState copyWith({
    TrackingLoadStatus? loadStatus,
    bool? hasConsented,
    bool? isSubmittingConsent,
    bool? hasLocationPermission,
    bool? isTrackingActive,
    bool? isTogglingTracking,
    LocationStatus? currentStatus,
    LocationPoint? lastPoint,
    bool clearLastPoint = false,
    DateTime? lastUpdatedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TrackingState(
      loadStatus: loadStatus ?? this.loadStatus,
      hasConsented: hasConsented ?? this.hasConsented,
      isSubmittingConsent: isSubmittingConsent ?? this.isSubmittingConsent,
      hasLocationPermission:
          hasLocationPermission ?? this.hasLocationPermission,
      isTrackingActive: isTrackingActive ?? this.isTrackingActive,
      isTogglingTracking: isTogglingTracking ?? this.isTogglingTracking,
      currentStatus: currentStatus ?? this.currentStatus,
      lastPoint: clearLastPoint ? null : (lastPoint ?? this.lastPoint),
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    loadStatus,
    hasConsented,
    isSubmittingConsent,
    hasLocationPermission,
    isTrackingActive,
    isTogglingTracking,
    currentStatus,
    lastPoint,
    lastUpdatedAt,
    errorMessage,
  ];
}
