import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/project_repository.dart';
import 'projects_list_event.dart';
import 'projects_list_state.dart';

/// Loads the paginated `/projects` list (all projects the caller can see —
/// gated upstream by whichever of `project:view_all` /
/// `project:view_assigned` the caller holds), optionally filtered by status.
class ProjectsListBloc extends Bloc<ProjectsListEvent, ProjectsListState> {
  ProjectsListBloc(this._projectRepository)
    : super(const ProjectsListState()) {
    on<ProjectsListRequested>(_onRequested);
  }

  final ProjectRepository _projectRepository;

  Future<void> _onRequested(
    ProjectsListRequested event,
    Emitter<ProjectsListState> emit,
  ) async {
    emit(ProjectsListState(projects: state.projects, isLoading: true));
    try {
      final result = await _projectRepository.list(status: event.status);
      emit(ProjectsListState(projects: result.projects, isLoading: false));
    } on ApiException catch (e) {
      emit(
        ProjectsListState(
          projects: state.projects,
          isLoading: false,
          error: e.message,
        ),
      );
    }
  }
}
