import 'package:flutter/material.dart';

import 'package:mobile/core/auth/permission.dart';

/// Mirrors `backend/app/models/enums.py::LocationStatus` exactly — the
/// server-computed geofence status for a user's most recent location point.
/// Every wire value is handled distinctly in the UI; none are collapsed.
///
/// Priority order the backend applies when computing this (see
/// `app/services/location_service.py::LocationService._compute_status`):
/// locationDisabled > unknown > offline > outsideTrackingHours >
/// noAssignedProject > insideAssigned/nearAssigned >
/// insideOtherAccessible/insideOtherUnauthorized > outsideAssigned.
enum LocationStatus {
  insideAssigned('inside_assigned'),
  nearAssigned('near_assigned'),
  outsideAssigned('outside_assigned'),
  insideOtherAccessible('inside_other_accessible'),
  insideOtherUnauthorized('inside_other_unauthorized'),
  noAssignedProject('no_assigned_project'),
  locationDisabled('location_disabled'),
  offline('offline'),
  outsideTrackingHours('outside_tracking_hours'),
  unknown('unknown');

  const LocationStatus(this.value);

  /// The wire value the backend sends/expects.
  final String value;

  static LocationStatus fromWire(String value) {
    return LocationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () =>
          throw ArgumentError('Unknown location status wire value: $value'),
    );
  }

  /// Human-readable label for status chips, banners, and marker info cards.
  String get label => switch (this) {
    LocationStatus.insideAssigned => 'Inside assigned site',
    LocationStatus.nearAssigned => 'Near assigned site (within range)',
    LocationStatus.outsideAssigned => 'Outside assigned site',
    LocationStatus.insideOtherAccessible => 'Inside another site (visible)',
    LocationStatus.insideOtherUnauthorized =>
      'Inside another site (unauthorized)',
    LocationStatus.noAssignedProject => 'No active assignment',
    LocationStatus.locationDisabled => 'Tracking disabled by company',
    LocationStatus.offline => 'Offline — no recent signal',
    LocationStatus.outsideTrackingHours => 'Outside company tracking hours',
    LocationStatus.unknown => 'Unknown — no location yet',
  };

  /// Marker/badge color for this status.
  Color get color => switch (this) {
    LocationStatus.insideAssigned => Colors.green,
    LocationStatus.nearAssigned => Colors.lightGreen,
    LocationStatus.outsideAssigned => Colors.orange,
    LocationStatus.insideOtherAccessible => Colors.blue,
    LocationStatus.insideOtherUnauthorized => Colors.red,
    LocationStatus.noAssignedProject => Colors.grey,
    LocationStatus.locationDisabled => Colors.blueGrey,
    LocationStatus.offline => Colors.brown,
    LocationStatus.outsideTrackingHours => Colors.amber,
    LocationStatus.unknown => Colors.grey.shade400,
  };
}

/// Mirrors `backend/app/schemas/location.py::LocationPointPublic`.
class LocationPoint {
  const LocationPoint({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    this.accuracyMeters,
    required this.isMockLocation,
    this.batteryPercent,
    required this.recordedAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final double lat;
  final double lng;
  final double? accuracyMeters;
  final bool isMockLocation;
  final int? batteryPercent;
  final DateTime recordedAt;
  final DateTime createdAt;

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
      isMockLocation: json['is_mock_location'] as bool,
      batteryPercent: json['battery_percent'] as int?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Mirrors `backend/app/schemas/location.py::LocationStatusPublic` — the
/// response of both `POST /locations` and `GET /locations/me`.
class LocationStatusResult {
  const LocationStatusResult({required this.status, this.point});

  final LocationStatus status;
  final LocationPoint? point;

  factory LocationStatusResult.fromJson(Map<String, dynamic> json) {
    return LocationStatusResult(
      status: LocationStatus.fromWire(json['status'] as String),
      point: json['point'] == null
          ? null
          : LocationPoint.fromJson(json['point'] as Map<String, dynamic>),
    );
  }
}

/// Mirrors `backend/app/schemas/location.py::TeamMemberStatus` — one row per
/// team member returned by `GET /locations/team`.
class TeamMemberStatus {
  const TeamMemberStatus({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.status,
    this.point,
  });

  final String userId;
  final String fullName;
  final Role role;
  final LocationStatus status;
  final LocationPoint? point;

  factory TeamMemberStatus.fromJson(Map<String, dynamic> json) {
    return TeamMemberStatus(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      role: Role.fromWire(json['role'] as String),
      status: LocationStatus.fromWire(json['status'] as String),
      point: json['point'] == null
          ? null
          : LocationPoint.fromJson(json['point'] as Map<String, dynamic>),
    );
  }
}
