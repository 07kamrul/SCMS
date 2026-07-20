import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/project_models.dart';
import '../data/project_repository.dart';
import 'project_form_event.dart';
import 'project_form_state.dart';

/// Drives the create/edit project form, including the draw-by-tap polygon
/// boundary editor.
class ProjectFormBloc extends Bloc<ProjectFormEvent, ProjectFormState> {
  ProjectFormBloc(this._projectRepository) : super(const ProjectFormState()) {
    on<PolygonPointAdded>(_onPointAdded);
    on<PolygonPointRemoved>(_onPointRemoved);
    on<PolygonCleared>(_onCleared);
    on<ProjectFormSubmitted>(_onSubmitted);
  }

  final ProjectRepository _projectRepository;

  void _onPointAdded(PolygonPointAdded event, Emitter<ProjectFormState> emit) {
    emit(
      ProjectFormState(
        drawnPoints: [...state.drawnPoints, event.point],
      ),
    );
  }

  void _onPointRemoved(
    PolygonPointRemoved event,
    Emitter<ProjectFormState> emit,
  ) {
    final updated = List.of(state.drawnPoints)..removeAt(event.index);
    emit(ProjectFormState(drawnPoints: updated));
  }

  void _onCleared(PolygonCleared event, Emitter<ProjectFormState> emit) {
    emit(const ProjectFormState());
  }

  Future<void> _onSubmitted(
    ProjectFormSubmitted event,
    Emitter<ProjectFormState> emit,
  ) async {
    emit(ProjectFormState(drawnPoints: state.drawnPoints, isSubmitting: true));

    final boundary = state.hasEnoughPointsForBoundary
        ? GeoJsonPolygon.fromLatLngRing(state.drawnPoints)
        : null;

    try {
      final project = event.projectId != null
          ? await _projectRepository.update(
              event.projectId!,
              name: event.name,
              description: event.description,
              status: event.status,
              boundary: boundary,
            )
          : await _projectRepository.create(
              name: event.name,
              description: event.description,
              status: event.status,
              boundary: boundary,
            );
      emit(
        ProjectFormState(
          drawnPoints: state.drawnPoints,
          submittedProject: project,
        ),
      );
    } on ApiException catch (e) {
      emit(
        ProjectFormState(
          drawnPoints: state.drawnPoints,
          error: e.message,
        ),
      );
    }
  }
}
