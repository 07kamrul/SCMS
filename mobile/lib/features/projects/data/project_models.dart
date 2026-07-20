import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Mirrors `backend/app/models/enums.py::ProjectStatus` exactly.
///
/// `label`/`color` follow the same display convention as
/// `features/tasks/data/task_models.dart::TaskStatus` and
/// `features/issues/data/issue_models.dart::IssueStatus` — every presentation
/// widget that renders a project's status (list, map polygons) reuses these
/// instead of inventing its own palette.
enum ProjectStatus {
  planned('planned', 'Planned', Colors.grey),
  running('running', 'Running', Colors.green),
  onHold('on_hold', 'On Hold', Colors.amber),
  delayed('delayed', 'Delayed', Colors.red),
  completed('completed', 'Completed', Colors.teal),
  archived('archived', 'Archived', Colors.blueGrey);

  const ProjectStatus(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static ProjectStatus fromWire(String value) {
    return ProjectStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () =>
          throw ArgumentError('Unknown project status wire value: $value'),
    );
  }

  String toWire() => value;
}

/// Mirrors `backend/app/schemas/project.py::GeoJSONPolygon` — a GeoJSON
/// Polygon carrying a single ring (no holes) of `[lng, lat]` positions, with
/// the ring closed (first position == last position).
///
/// GeoJSON/GIS convention is `[lng, lat]` order; `flutter_map`'s [LatLng]
/// (from `latlong2`) is `(lat, lng)` order, hence the explicit swap helpers
/// below rather than reusing [LatLng] as the storage type.
class GeoJsonPolygon {
  const GeoJsonPolygon(this.ring);

  /// The single exterior ring, each position as `[lng, lat]`.
  final List<List<double>> ring;

  factory GeoJsonPolygon.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordinates'] as List<dynamic>;
    final outerRing = coordinates.first as List<dynamic>;
    return GeoJsonPolygon(
      outerRing
          .map(
            (position) => (position as List<dynamic>)
                .map((coordinate) => (coordinate as num).toDouble())
                .toList(),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {'type': 'Polygon', 'coordinates': [ring]};

  /// Swaps `[lng, lat]` positions to `latlong2`'s `LatLng(lat, lng)` order
  /// for rendering with `flutter_map`'s `PolygonLayer`.
  List<LatLng> toLatLngRing() =>
      ring.map((position) => LatLng(position[1], position[0])).toList();

  /// Builds a boundary from user-drawn map points, swapping back to
  /// `[lng, lat]` order and automatically closing the ring (appending the
  /// first point again) if the caller didn't already close it.
  factory GeoJsonPolygon.fromLatLngRing(List<LatLng> points) {
    final ring = points
        .map((point) => [point.longitude, point.latitude])
        .toList();
    final isAlreadyClosed =
        ring.isNotEmpty &&
        ring.first[0] == ring.last[0] &&
        ring.first[1] == ring.last[1];
    if (ring.isNotEmpty && !isAlreadyClosed) {
      ring.add(List<double>.from(ring.first));
    }
    return GeoJsonPolygon(ring);
  }
}

/// Mirrors `backend/app/schemas/project.py::ProjectPublic`.
class Project {
  const Project({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    required this.status,
    required this.progressPercent,
    this.boundary,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String? description;
  final ProjectStatus status;
  final int progressPercent;
  final GeoJsonPolygon? boundary;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: ProjectStatus.fromWire(json['status'] as String),
      progressPercent: json['progress_percent'] as int,
      boundary: json['boundary'] == null
          ? null
          : GeoJsonPolygon.fromJson(json['boundary'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
