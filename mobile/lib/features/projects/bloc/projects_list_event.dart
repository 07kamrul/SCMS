import 'package:equatable/equatable.dart';

import '../data/project_models.dart';

/// Events consumed by [ProjectsListBloc].
sealed class ProjectsListEvent extends Equatable {
  const ProjectsListEvent();

  @override
  List<Object?> get props => [];
}

/// Fired to (re)load the paginated project list, optionally filtered by
/// [status]. Fired on page init and whenever the caller changes the filter.
final class ProjectsListRequested extends ProjectsListEvent {
  const ProjectsListRequested({this.status});

  final ProjectStatus? status;

  @override
  List<Object?> get props => [status];
}
