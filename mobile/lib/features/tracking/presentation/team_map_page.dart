import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/error_view.dart';
import 'package:mobile/shared/widgets/loading_view.dart';

import '../bloc/team_map_bloc.dart';
import '../bloc/team_map_event.dart';
import '../bloc/team_map_state.dart';
import '../data/location_models.dart';
import 'location_status_widgets.dart';

/// The manager's live team map (`GET /locations/team`): every visible team
/// member rendered as a color-coded marker matching the [LocationStatus]
/// palette used by the employee-facing status banner. Tapping a marker shows
/// that person's name, status, and last-seen time.
///
/// Uses `flutter_map` against OpenStreetMap tiles — Google Maps is
/// prohibited by the PRD.
class TeamMapPage extends StatelessWidget {
  const TeamMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TeamMapBloc>()..add(const TeamMapRequested()),
      child: const _TeamMapView(),
    );
  }
}

class _TeamMapView extends StatelessWidget {
  const _TeamMapView();

  void _showLegend(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LocationStatusLegend(),
      ),
    );
  }

  void _showMemberDetail(BuildContext context, TeamMemberStatus member) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.fullName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              member.role.value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            LocationStatusBanner(
              status: member.status,
              lastUpdatedAt: member.point?.recordedAt,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Map'),
        actions: [
          IconButton(
            tooltip: 'Status legend',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showLegend(context),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<TeamMapBloc>().add(const TeamMapRequested()),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<TeamMapBloc, TeamMapState>(
          builder: (context, state) => _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TeamMapState state) {
    if (state.isLoading && state.members.isEmpty) {
      return const LoadingView();
    }
    if (state.error != null && state.members.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () =>
            context.read<TeamMapBloc>().add(const TeamMapRequested()),
      );
    }

    final located = state.members
        .where((member) => member.point != null)
        .toList();
    if (located.isEmpty) {
      return const Center(
        child: Text('No team member locations available yet.'),
      );
    }

    final center = LatLng(
      located.map((m) => m.point!.lat).reduce((a, b) => a + b) /
          located.length,
      located.map((m) => m.point!.lng).reduce((a, b) => a + b) /
          located.length,
    );

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.scfms.mobile',
        ),
        MarkerLayer(
          markers: [
            for (final member in located)
              Marker(
                point: LatLng(member.point!.lat, member.point!.lng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _showMemberDetail(context, member),
                  child: Icon(
                    Icons.location_on,
                    color: member.status.color,
                    size: 40,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
