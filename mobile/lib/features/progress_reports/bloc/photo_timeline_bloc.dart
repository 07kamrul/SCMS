import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/progress_report_models.dart';
import '../data/progress_report_repository.dart';
import 'photo_timeline_event.dart';
import 'photo_timeline_state.dart';

/// Loads a project's full site-photo timeline and groups it by calendar day
/// for date-sectioned display. `GET /progress-reports/timeline` returns a
/// flat, chronological list across the whole project — the server does no
/// date-grouping, so that's done here.
class PhotoTimelineBloc extends Bloc<PhotoTimelineEvent, PhotoTimelineState> {
  PhotoTimelineBloc(this._repository) : super(const PhotoTimelineInitial()) {
    on<PhotoTimelineRequested>(_onRequested);
  }

  final ProgressReportRepository _repository;

  Future<void> _onRequested(
    PhotoTimelineRequested event,
    Emitter<PhotoTimelineState> emit,
  ) async {
    emit(const PhotoTimelineLoading());
    try {
      final photos = await _repository.timeline(projectId: event.projectId);
      final grouped = <DateTime, List<ProgressPhotoEntry>>{};
      for (final photo in photos) {
        final createdAt = photo.createdAt;
        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        (grouped[day] ??= []).add(photo);
      }
      final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
      final sorted = {for (final day in sortedDays) day: grouped[day]!};
      emit(PhotoTimelineLoaded(sorted));
    } on ApiException catch (e) {
      emit(PhotoTimelineFailure(e.message));
    }
  }
}
