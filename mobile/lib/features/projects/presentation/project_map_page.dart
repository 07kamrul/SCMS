import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../bloc/project_map_bloc.dart';
import '../bloc/project_map_event.dart';
import '../bloc/project_map_state.dart';
import '../data/project_models.dart';
import 'project_form_page.dart';
import 'widgets/osm_map_layers.dart';
import 'widgets/project_status_chip.dart';

/// All-projects map view (`/projects/map`, driven by [ProjectMapBloc]):
/// every project's boundary polygon, colored by [ProjectStatus.color],
/// tappable to show a details panel.
///
/// When [focusedProjectId] is set (e.g. arriving from a list-item tap), the
/// camera fits that project's boundary and its panel opens immediately —
/// there is no separate "project detail" bloc in this feature, so the
/// detail view is just this map with a project pre-selected.
class ProjectMapPage extends StatelessWidget {
  const ProjectMapPage({super.key, this.focusedProjectId, this.canEdit = false});

  final String? focusedProjectId;

  /// Gates the "Edit boundary" action in the selected-project panel —
  /// mirrors `Permission.projectUpdate`, decided by the caller.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProjectMapBloc>()..add(const ProjectMapRequested()),
      child: _ProjectMapView(focusedProjectId: focusedProjectId, canEdit: canEdit),
    );
  }
}

class _ProjectMapView extends StatefulWidget {
  const _ProjectMapView({required this.focusedProjectId, required this.canEdit});

  final String? focusedProjectId;
  final bool canEdit;

  @override
  State<_ProjectMapView> createState() => _ProjectMapViewState();
}

class _ProjectMapViewState extends State<_ProjectMapView> {
  final _mapController = MapController();
  final LayerHitNotifier<String> _hitNotifier = ValueNotifier(null);

  String? _selectedProjectId;
  bool _hasFitCamera = false;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.focusedProjectId;
    _hitNotifier.addListener(_onHit);
  }

  @override
  void dispose() {
    _hitNotifier.removeListener(_onHit);
    super.dispose();
  }

  void _onHit() {
    final hit = _hitNotifier.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    setState(() => _selectedProjectId = hit.hitValues.first);
  }

  void _fitCameraIfNeeded(List<Project> projects) {
    if (_hasFitCamera) return;
    final withBoundary = projects.where((p) => p.boundary != null);
    final focused = widget.focusedProjectId == null
        ? null
        : withBoundary.firstWhereOrNull((p) => p.id == widget.focusedProjectId);
    final ringsToFit = focused != null
        ? [focused.boundary!.toLatLngRing()]
        : withBoundary.map((p) => p.boundary!.toLatLngRing());
    final points = [for (final ring in ringsToFit) ...ring];
    if (points.isEmpty) return;
    _hasFitCamera = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(40),
        ),
      );
    });
  }

  Future<void> _editSelected(Project project) async {
    final bloc = context.read<ProjectMapBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProjectFormPage(project: project)),
    );
    if (mounted) {
      bloc.add(const ProjectMapRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Map')),
      body: BlocBuilder<ProjectMapBloc, ProjectMapState>(
        builder: (context, state) {
          if (state.isLoading && state.projects.isEmpty) {
            return const LoadingView();
          }
          if (state.error != null && state.projects.isEmpty) {
            return ErrorView(
              message: state.error!,
              onRetry: () => context.read<ProjectMapBloc>().add(
                const ProjectMapRequested(),
              ),
            );
          }

          _fitCameraIfNeeded(state.projects);
          final projectsWithBoundary = state.projects
              .where((p) => p.boundary != null)
              .toList();
          final selected = _selectedProjectId == null
              ? null
              : state.projects.firstWhereOrNull(
                  (p) => p.id == _selectedProjectId,
                );

          return Stack(
            children: [
              GestureDetector(
                onTap: () {}, // required for hitNotifier taps to register
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(20, 0),
                    initialZoom: 2,
                  ),
                  children: [
                    ...osmMapLayers(),
                    PolygonLayer<String>(
                      hitNotifier: _hitNotifier,
                      polygons: [
                        for (final project in projectsWithBoundary)
                          Polygon<String>(
                            points: project.boundary!.toLatLngRing(),
                            color: project.status.color.withValues(
                              alpha: project.id == _selectedProjectId
                                  ? 0.45
                                  : 0.25,
                            ),
                            borderColor: project.status.color,
                            borderStrokeWidth:
                                project.id == _selectedProjectId ? 4 : 2,
                            hitValue: project.id,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: _MapOverlayAlign(
                  child: _StatusLegend(
                    projectsWithoutBoundary:
                        state.projects.length - projectsWithBoundary.length,
                  ),
                ),
              ),
              if (selected != null)
                Positioned(
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: _MapOverlayAlign(
                    child: _SelectedProjectPanel(
                      project: selected,
                      canEdit: widget.canEdit,
                      onEdit: () => _editSelected(selected),
                      onClose: () => setState(() => _selectedProjectId = null),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Keeps the map's floating overlay cards (`_StatusLegend`,
/// `_SelectedProjectPanel`) from stretching edge-to-edge on tablet-width
/// windows, where a full-bleed card reads as an overflow-adjacent visual
/// bug rather than a deliberate layout — centers with a readable max width
/// instead. On compact windows this is a no-op (full available width).
class _MapOverlayAlign extends StatelessWidget {
  const _MapOverlayAlign({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: child,
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend({required this.projectsWithoutBoundary});

  final int projectsWithoutBoundary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final status in ProjectStatus.values)
                  ProjectStatusChip(status: status),
              ],
            ),
            if (projectsWithoutBoundary > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$projectsWithoutBoundary project(s) have no boundary drawn yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedProjectPanel extends StatelessWidget {
  const _SelectedProjectPanel({
    required this.project,
    required this.canEdit,
    required this.onEdit,
    required this.onClose,
  });

  final Project project;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (project.description != null &&
                project.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(project.description!),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                ProjectStatusChip(status: project.status),
                const SizedBox(width: AppSpacing.sm),
                Text('${project.progressPercent}% complete'),
              ],
            ),
            if (project.boundary == null)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text('No boundary polygon drawn yet.'),
              ),
            if (canEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: onEdit,
                  child: Text(
                    project.boundary == null ? 'Draw boundary' : 'Edit boundary',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
