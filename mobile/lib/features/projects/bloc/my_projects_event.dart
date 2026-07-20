import 'package:equatable/equatable.dart';

/// Events consumed by [MyProjectsBloc].
sealed class MyProjectsEvent extends Equatable {
  const MyProjectsEvent();

  @override
  List<Object?> get props => [];
}

/// Fired to (re)load the caller's active-assignment projects.
final class MyProjectsRequested extends MyProjectsEvent {
  const MyProjectsRequested();
}
