import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/project_repository.dart';
import 'my_projects_event.dart';
import 'my_projects_state.dart';

/// "My Projects" view for assignment-scoped roles (Site Engineer,
/// Employee): loads the caller's full assignment history via
/// `/assignments/me`, keeps only the active (not-yet-ended) ones, then
/// resolves each to its project via `/projects/map` (fetched once and
/// filtered client-side — avoids one `/projects/{id}` round trip per
/// assignment).
class MyProjectsBloc extends Bloc<MyProjectsEvent, MyProjectsState> {
  MyProjectsBloc(this._projectRepository) : super(const MyProjectsState()) {
    on<MyProjectsRequested>(_onRequested);
  }

  final ProjectRepository _projectRepository;

  Future<void> _onRequested(
    MyProjectsRequested event,
    Emitter<MyProjectsState> emit,
  ) async {
    emit(MyProjectsState(items: state.items, isLoading: true));
    try {
      final assignments = await _projectRepository.myAssignments();
      final activeAssignments = assignments.where((a) => a.isActive);

      final allProjects = await _projectRepository.listForMap();
      final projectsById = {for (final p in allProjects) p.id: p};

      final items = [
        for (final assignment in activeAssignments)
          if (projectsById[assignment.projectId] case final project?)
            MyProjectItem(project: project, assignment: assignment),
      ];

      emit(MyProjectsState(items: items, isLoading: false));
    } on ApiException catch (e) {
      emit(
        MyProjectsState(items: state.items, isLoading: false, error: e.message),
      );
    }
  }
}
