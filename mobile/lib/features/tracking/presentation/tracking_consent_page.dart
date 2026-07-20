import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/loading_view.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import '../bloc/tracking_bloc.dart';
import '../bloc/tracking_event.dart';
import '../bloc/tracking_state.dart';
import 'location_status_widgets.dart';

const double _kMaxContentWidth = 560;

/// Consent gate + always-visible status indicator for the employee's own
/// location sharing. Explains what is tracked, gates the start/stop toggle
/// behind consent, and — once consented — always shows the current
/// [LocationStatus] via [LocationStatusBanner], the in-app half of the
/// PRD's "always-visible tracking indicator" (the OS notification from
/// `flutter_foreground_task` is the background half, shown for as long as
/// the foreground service runs, even if this page isn't open).
class TrackingConsentPage extends StatelessWidget {
  const TrackingConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TrackingBloc>()..add(const TrackingStarted()),
      child: const _TrackingConsentView(),
    );
  }
}

class _TrackingConsentView extends StatelessWidget {
  const _TrackingConsentView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Sharing')),
      body: SafeArea(
        child: BlocConsumer<TrackingBloc, TrackingState>(
          listenWhen: (previous, current) =>
              current.errorMessage != null &&
              current.errorMessage != previous.errorMessage,
          listener: (context, state) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          },
          builder: (context, state) {
            if (state.loadStatus == TrackingLoadStatus.initial ||
                (state.loadStatus == TrackingLoadStatus.loading &&
                    !state.hasConsented)) {
              return const LoadingView();
            }
            final content = RefreshIndicator(
              onRefresh: () async {
                context.read<TrackingBloc>().add(
                  const TrackingStatusRefreshed(),
                );
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: state.hasConsented
                    ? _consentedContent(context, state)
                    : _consentGateContent(context, state),
              ),
            );
            return ResponsiveScaffold(
              compact: (context) => content,
              expanded: (context) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _consentGateContent(BuildContext context, TrackingState state) {
    return [
      const Icon(Icons.location_on_outlined, size: 56),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Share your location with your company',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'While location sharing is on, your position is periodically sent '
        'to your company so your managers can see whether you are at an '
        'assigned project site. Your device shows a persistent '
        'notification the entire time sharing is active, and you can stop '
        'sharing at any time.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: state.isSubmittingConsent
            ? null
            : () => context.read<TrackingBloc>().add(
                const TrackingConsentRequested(),
              ),
        child: state.isSubmittingConsent
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('I agree — enable location sharing'),
      ),
      const SizedBox(height: AppSpacing.lg),
      ExpansionTile(
        title: const Text('What do the status colors mean?'),
        tilePadding: EdgeInsets.zero,
        children: const [LocationStatusLegend()],
      ),
    ];
  }

  List<Widget> _consentedContent(BuildContext context, TrackingState state) {
    return [
      LocationStatusBanner(
        status: state.currentStatus,
        lastUpdatedAt: state.lastUpdatedAt,
      ),
      const SizedBox(height: AppSpacing.md),
      if (state.isTrackingActive)
        FilledButton.tonalIcon(
          onPressed: state.isTogglingTracking
              ? null
              : () => context.read<TrackingBloc>().add(
                  const TrackingStopRequested(),
                ),
          icon: const Icon(Icons.stop_circle_outlined),
          label: state.isTogglingTracking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Stop sharing my location'),
        )
      else
        FilledButton.icon(
          onPressed: state.isTogglingTracking
              ? null
              : () => context.read<TrackingBloc>().add(
                  const TrackingStartRequested(),
                ),
          icon: const Icon(Icons.play_circle_outline),
          label: state.isTogglingTracking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Start sharing my location'),
        ),
      const SizedBox(height: AppSpacing.sm),
      if (state.isTrackingActive)
        const Text(
          'A persistent notification confirms sharing is active in the '
          'background.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      const SizedBox(height: AppSpacing.lg),
      ExpansionTile(
        title: const Text('What do the status colors mean?'),
        tilePadding: EdgeInsets.zero,
        children: const [LocationStatusLegend()],
      ),
    ];
  }
}
