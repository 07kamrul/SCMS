import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../data/project_models.dart';

/// State for [ProjectFormBloc].
class ProjectFormState extends Equatable {
  const ProjectFormState({
    this.drawnPoints = const [],
    this.isSubmitting = false,
    this.error,
    this.submittedProject,
  });

  /// Vertices the user has tapped so far, in `flutter_map`'s `(lat, lng)`
  /// order — converted to a closed GeoJSON ring only on submit.
  final List<LatLng> drawnPoints;

  final bool isSubmitting;
  final String? error;

  /// Set once `create()`/`update()` succeeds — the UI observes this via a
  /// `BlocListener` to navigate away.
  final Project? submittedProject;

  /// A polygon needs at least 3 distinct vertices (a triangle) before it can
  /// be sent as a boundary.
  bool get hasEnoughPointsForBoundary => drawnPoints.length >= 3;

  @override
  List<Object?> get props => [
    drawnPoints,
    isSubmitting,
    error,
    submittedProject,
  ];
}
