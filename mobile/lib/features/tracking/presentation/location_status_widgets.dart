import 'package:flutter/material.dart';

import '../data/location_models.dart';

/// A small colored dot for a [LocationStatus] — the shared visual building
/// block behind the banner, legend, and map markers so the same 10 colors
/// mean the same thing everywhere in the tracking feature.
class LocationStatusDot extends StatelessWidget {
  const LocationStatusDot({super.key, required this.status, this.size = 12});

  final LocationStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
    );
  }
}

/// The always-visible, in-app half of the PRD's "always-visible tracking
/// indicator" requirement (the OS notification from `flutter_foreground_task`
/// is the background half). Renders every one of the 10 [LocationStatus]
/// values with a distinct color and label — none collapsed together.
class LocationStatusBanner extends StatelessWidget {
  const LocationStatusBanner({
    super.key,
    required this.status,
    this.lastUpdatedAt,
  });

  final LocationStatus status;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          LocationStatusDot(status: status, size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (lastUpdatedAt != null)
                  Text(
                    'Updated ${_relativeTime(lastUpdatedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// A compact reference list of all 10 [LocationStatus] values with their
/// color + label, so the meaning of a banner or map-marker color is always
/// one tap away. Used both as an expandable "what do these mean?" section on
/// the consent page and as the manager map's color legend.
class LocationStatusLegend extends StatelessWidget {
  const LocationStatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final status in LocationStatus.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                LocationStatusDot(status: status),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
