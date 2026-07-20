import 'package:equatable/equatable.dart';

/// Events consumed by [ProjectMapBloc].
sealed class ProjectMapEvent extends Equatable {
  const ProjectMapEvent();

  @override
  List<Object?> get props => [];
}

/// Fired to (re)load every project the caller can see, for map rendering.
final class ProjectMapRequested extends ProjectMapEvent {
  const ProjectMapRequested();
}
