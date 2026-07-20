import 'package:equatable/equatable.dart';

import '../data/progress_report_models.dart';

/// States emitted by [PhotoTimelineBloc].
sealed class PhotoTimelineState extends Equatable {
  const PhotoTimelineState();

  @override
  List<Object?> get props => [];
}

final class PhotoTimelineInitial extends PhotoTimelineState {
  const PhotoTimelineInitial();
}

final class PhotoTimelineLoading extends PhotoTimelineState {
  const PhotoTimelineLoading();
}

/// [photosByDay] groups the flat server timeline by calendar day (dates
/// truncated to midnight, local time), ordered most-recent-day-first, ready
/// for the presentation layer to render as date-sectioned content.
final class PhotoTimelineLoaded extends PhotoTimelineState {
  const PhotoTimelineLoaded(this.photosByDay);

  final Map<DateTime, List<ProgressPhotoEntry>> photosByDay;

  @override
  List<Object?> get props => [photosByDay];
}

final class PhotoTimelineFailure extends PhotoTimelineState {
  const PhotoTimelineFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
