import 'package:equatable/equatable.dart';

/// Events consumed by [PhotoTimelineBloc].
sealed class PhotoTimelineEvent extends Equatable {
  const PhotoTimelineEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the timeline page opens — loads the full photo timeline for
/// [projectId].
final class PhotoTimelineRequested extends PhotoTimelineEvent {
  const PhotoTimelineRequested(this.projectId);

  final String projectId;

  @override
  List<Object?> get props => [projectId];
}
