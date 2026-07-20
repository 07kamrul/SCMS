import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_breakpoints.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/shared/widgets/error_view.dart';
import 'package:mobile/shared/widgets/loading_view.dart';

import '../bloc/photo_timeline_bloc.dart';
import '../bloc/photo_timeline_event.dart';
import '../bloc/photo_timeline_state.dart';
import '../data/progress_report_models.dart';

/// Site photo timeline for a whole project: every progress-report photo,
/// grouped client-side by calendar day and rendered as a scrolling grid
/// with date-section headers.
class ProjectPhotoTimelinePage extends StatelessWidget {
  const ProjectPhotoTimelinePage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PhotoTimelineBloc>()..add(PhotoTimelineRequested(projectId)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Site Photo Timeline')),
        body: BlocBuilder<PhotoTimelineBloc, PhotoTimelineState>(
          builder: (context, state) => switch (state) {
            PhotoTimelineInitial() || PhotoTimelineLoading() => const LoadingView(),
            PhotoTimelineFailure(:final message) => ErrorView(
              message: message,
              onRetry: () =>
                  context.read<PhotoTimelineBloc>().add(PhotoTimelineRequested(projectId)),
            ),
            PhotoTimelineLoaded(:final photosByDay) => photosByDay.isEmpty
                ? const Center(child: Text('No photos yet.'))
                : _TimelineGrid(photosByDay: photosByDay),
          },
        ),
      ),
    );
  }
}

class _TimelineGrid extends StatelessWidget {
  const _TimelineGrid({required this.photosByDay});

  final Map<DateTime, List<ProgressPhotoEntry>> photosByDay;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = context.isCompact ? 3 : 5;
    return ListView(
      children: [
        for (final entry in photosByDay.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              DateFormat.yMMMMd().format(entry.key),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: entry.value.length,
            itemBuilder: (context, index) {
              final photo = entry.value[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => _PhotoFullScreenPage(photo: photo)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm / 2),
                  child: Image.network(
                    photo.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PhotoFullScreenPage extends StatelessWidget {
  const _PhotoFullScreenPage({required this.photo});

  final ProgressPhotoEntry photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Image.network(
                  photo.photoUrl,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.white, size: 64),
                ),
              ),
            ),
          ),
          if (photo.caption != null && photo.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(photo.caption!, style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
