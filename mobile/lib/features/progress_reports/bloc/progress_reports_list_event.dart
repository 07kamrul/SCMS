import 'package:equatable/equatable.dart';

/// Events consumed by [ProgressReportsListBloc].
sealed class ProgressReportsListEvent extends Equatable {
  const ProgressReportsListEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the list page opens (or pulls to refresh) — (re)loads page 1
/// for [projectId].
final class ProgressReportsListStarted extends ProgressReportsListEvent {
  const ProgressReportsListStarted(this.projectId);

  final String projectId;

  @override
  List<Object?> get props => [projectId];
}

/// Fired on scroll-to-bottom to load the next page. A no-op if the bloc
/// isn't currently in a loaded state with more pages available.
final class ProgressReportsListMoreRequested extends ProgressReportsListEvent {
  const ProgressReportsListMoreRequested();
}
