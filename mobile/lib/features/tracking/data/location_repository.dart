import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/envelope.dart';

import 'location_models.dart';

/// Repository for the tracking feature. Wraps [ApiClient] calls against
/// `/locations*`. Used both from the main isolate (employee self-status,
/// manager team map) and from inside the foreground-service isolate (see
/// `services/location_foreground_service.dart`), where a fresh [ApiClient]
/// is constructed directly rather than resolved through `getIt`.
class LocationRepository {
  LocationRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Submits one GPS fix. `recordedAt` must be the time the fix was taken
  /// (not the time it's uploaded) — the backend uses it both for staleness
  /// (`OFFLINE`) and tracking-hours-window checks.
  Future<LocationStatusResult> reportLocation({
    required double lat,
    required double lng,
    double? accuracyMeters,
    required DateTime recordedAt,
    bool isMockLocation = false,
    int? batteryPercent,
  }) async {
    final envelope = await _apiClient.post<LocationStatusResult>(
      '/locations',
      body: {
        'lat': lat,
        'lng': lng,
        if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'is_mock_location': isMockLocation,
        if (batteryPercent != null) 'battery_percent': batteryPercent,
      },
      fromData: (json) =>
          LocationStatusResult.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// The calling (employee) user's own current geofence status.
  Future<LocationStatusResult> myStatus() async {
    final envelope = await _apiClient.get<LocationStatusResult>(
      '/locations/me',
      fromData: (json) =>
          LocationStatusResult.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// Team members visible to the caller's tracking-permission tier, for the
  /// manager live map.
  Future<List<TeamMemberStatus>> teamStatus() async {
    final envelope = await _apiClient.get<List<TeamMemberStatus>>(
      '/locations/team',
      fromData: (json) => listFromJson(json, TeamMemberStatus.fromJson),
    );
    return envelope.data!;
  }
}
