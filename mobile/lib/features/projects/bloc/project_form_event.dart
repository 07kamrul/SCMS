import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../data/project_models.dart';

/// Events consumed by [ProjectFormBloc].
sealed class ProjectFormEvent extends Equatable {
  const ProjectFormEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user taps the draw-by-tap map to add a polygon vertex.
final class PolygonPointAdded extends ProjectFormEvent {
  const PolygonPointAdded(this.point);

  final LatLng point;

  @override
  List<Object?> get props => [point];
}

/// Fired to remove a single vertex (e.g. undo the last tap).
final class PolygonPointRemoved extends ProjectFormEvent {
  const PolygonPointRemoved(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// Fired by the "clear" button — discards every drawn vertex.
final class PolygonCleared extends ProjectFormEvent {
  const PolygonCleared();
}

/// Fired when the user submits the form. Builds a [GeoJsonPolygon] from the
/// bloc's `drawnPoints` if there are 3 or more (a valid polygon needs at
/// least a triangle); otherwise no boundary is sent — for [projectId]
/// (edit mode) that leaves the project's existing boundary unchanged, since
/// [ProjectFormBloc] only sends non-null fields to `update()`.
final class ProjectFormSubmitted extends ProjectFormEvent {
  const ProjectFormSubmitted({
    required this.name,
    this.description,
    this.status = ProjectStatus.planned,
    this.projectId,
  });

  final String name;
  final String? description;
  final ProjectStatus status;

  /// Null for create; the existing project's id for edit.
  final String? projectId;

  @override
  List<Object?> get props => [name, description, status, projectId];
}
