import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/project_repository.dart';
import 'project_map_event.dart';
import 'project_map_state.dart';

/// Loads the unpaginated `/projects/map` list for the all-projects map view.
class ProjectMapBloc extends Bloc<ProjectMapEvent, ProjectMapState> {
  ProjectMapBloc(this._projectRepository) : super(const ProjectMapState()) {
    on<ProjectMapRequested>(_onRequested);
  }

  final ProjectRepository _projectRepository;

  Future<void> _onRequested(
    ProjectMapRequested event,
    Emitter<ProjectMapState> emit,
  ) async {
    emit(ProjectMapState(projects: state.projects, isLoading: true));
    try {
      final projects = await _projectRepository.listForMap();
      emit(ProjectMapState(projects: projects, isLoading: false));
    } on ApiException catch (e) {
      emit(
        ProjectMapState(
          projects: state.projects,
          isLoading: false,
          error: e.message,
        ),
      );
    }
  }
}
