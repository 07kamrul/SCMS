import 'package:equatable/equatable.dart';

import '../data/assignment_models.dart';
import '../data/project_models.dart';

/// A project the caller is currently (actively) assigned to, paired with
/// the assignment record that carries the caller's role on it.
class MyProjectItem extends Equatable {
  const MyProjectItem({required this.project, required this.assignment});

  final Project project;
  final Assignment assignment;

  @override
  List<Object?> get props => [project.id, assignment.id];
}

/// State for [MyProjectsBloc].
class MyProjectsState extends Equatable {
  const MyProjectsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<MyProjectItem> items;
  final bool isLoading;
  final String? error;

  @override
  List<Object?> get props => [items, isLoading, error];
}
