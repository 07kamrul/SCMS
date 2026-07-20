import 'package:equatable/equatable.dart';

import '../data/project_models.dart';

/// State for [ProjectMapBloc].
class ProjectMapState extends Equatable {
  const ProjectMapState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Project> projects;
  final bool isLoading;
  final String? error;

  @override
  List<Object?> get props => [projects, isLoading, error];
}
