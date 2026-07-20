import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../bloc/project_form_bloc.dart';
import '../bloc/project_form_event.dart';
import '../bloc/project_form_state.dart';
import '../data/project_models.dart';
import 'widgets/osm_map_layers.dart';

const double _kMaxFormWidth = 640;

/// Create/edit form for a project, including the tap-to-add-vertex polygon
/// boundary editor.
///
/// `project == null` creates a new project; otherwise the existing project
/// (already loaded by whichever page navigated here — there is no
/// `ProjectFormEvent` to fetch by id) is edited in place, with its boundary
/// preloaded into [ProjectFormBloc] by replaying [PolygonPointAdded] for each
/// existing vertex.
///
/// Ring-closing design choice: the user only needs to tap each vertex once
/// (no need to tap the first point again to close the loop) — submission
/// auto-closes the ring, mirroring `GeoJsonPolygon.fromLatLngRing`'s own
/// behavior in `data/project_models.dart`. [ProjectFormState.hasEnoughPointsForBoundary]
/// (>= 3 taps) is used to tell the user their drawn shape is a valid
/// triangle-or-more that will become a closed 4-plus-point boundary ring on
/// submit. The boundary itself stays optional — `ProjectFormBloc` only sends
/// it when `hasEnoughPointsForBoundary` is true, so the "Save" button is
/// gated on the required name field only, not on the boundary being drawn:
/// the backend already enforces that a project needs a boundary before its
/// status can become `running`, so requiring one at creation time would be
/// redundant and would block plain no-boundary/no-running project creation.
class ProjectFormPage extends StatelessWidget {
  const ProjectFormPage({super.key, this.project});

  final Project? project;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getIt<ProjectFormBloc>();
        final boundary = project?.boundary;
        if (boundary != null) {
          final ring = boundary.toLatLngRing();
          // The ring is closed (first == last); seed drawnPoints with only
          // the open vertex list, since submit re-closes it automatically.
          final openRing = ring.length > 1
              ? ring.sublist(0, ring.length - 1)
              : ring;
          for (final point in openRing) {
            bloc.add(PolygonPointAdded(point));
          }
        }
        return bloc;
      },
      child: _ProjectFormView(project: project),
    );
  }
}

class _ProjectFormView extends StatefulWidget {
  const _ProjectFormView({this.project});

  final Project? project;

  @override
  State<_ProjectFormView> createState() => _ProjectFormViewState();
}

class _ProjectFormViewState extends State<_ProjectFormView> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.project?.name ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.project?.description ?? '',
  );
  late ProjectStatus _status = widget.project?.status ?? ProjectStatus.planned;

  bool get _isEdit => widget.project != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ProjectFormBloc>().add(
      ProjectFormSubmitted(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        status: _status,
        projectId: widget.project?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit project' : 'New project')),
      body: SafeArea(
        child: BlocConsumer<ProjectFormBloc, ProjectFormState>(
          listenWhen: (previous, current) =>
              current.submittedProject != previous.submittedProject ||
              (current.error != null && current.error != previous.error),
          listener: (context, state) {
            if (state.submittedProject != null) {
              Navigator.of(context).pop(state.submittedProject);
            } else if (state.error != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
          builder: (context, state) {
            final form = Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Enter a project name'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<ProjectStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: ProjectStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(),
                    onChanged: (status) {
                      if (status != null) setState(() => _status = status);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Site boundary',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _BoundaryEditor(state: state),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.hasEnoughPointsForBoundary
                        ? '${state.drawnPoints.length} point(s) drawn — boundary ready (closes automatically on save).'
                        : '${state.drawnPoints.length} point(s) drawn — tap at least 3 points to define a boundary, or leave empty to skip it for now.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: state.isSubmitting ? null : _submit,
                    child: state.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Save changes' : 'Create project'),
                  ),
                ],
              ),
            );
            return ResponsiveScaffold(
              compact: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: form,
              ),
              expanded: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
                    child: form,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BoundaryEditor extends StatefulWidget {
  const _BoundaryEditor({required this.state});

  final ProjectFormState state;

  @override
  State<_BoundaryEditor> createState() => _BoundaryEditorState();
}

class _BoundaryEditorState extends State<_BoundaryEditor> {
  final _mapController = MapController();
  bool _hasCenteredOnExisting = false;

  @override
  Widget build(BuildContext context) {
    final points = widget.state.drawnPoints;
    if (!_hasCenteredOnExisting && points.isNotEmpty) {
      _hasCenteredOnExisting = true;
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

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: points.isNotEmpty
                  ? points.first
                  : const LatLng(20, 0),
              initialZoom: points.isNotEmpty ? 16 : 2,
              onTap: (_, point) => context.read<ProjectFormBloc>().add(
                PolygonPointAdded(point),
              ),
            ),
            children: [
              ...osmMapLayers(),
              if (points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.state.hasEnoughPointsForBoundary
                          ? [...points, points.first]
                          : points,
                      color: Colors.blue,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              if (widget.state.hasEnoughPointsForBoundary)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: points,
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderColor: Colors.transparent,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final (index, point) in points.indexed)
                    Marker(
                      point: point,
                      width: 28,
                      height: 28,
                      child: _VertexMarker(index: index),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: points.isEmpty
                  ? null
                  : () => context.read<ProjectFormBloc>().add(
                      PolygonPointRemoved(points.length - 1),
                    ),
              icon: const Icon(Icons.undo),
              label: const Text('Undo last point'),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: points.isEmpty
                  ? null
                  : () => context.read<ProjectFormBloc>().add(
                      const PolygonCleared(),
                    ),
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}

class _VertexMarker extends StatelessWidget {
  const _VertexMarker({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
