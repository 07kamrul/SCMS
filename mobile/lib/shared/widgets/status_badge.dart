import 'package:flutter/material.dart';

/// Generic colored chip for rendering a domain status (task/issue/project/
/// location status) that already carries its own `label`/`color`. Feature
/// enums expose those two fields directly — pass them straight through
/// rather than re-deriving color/label here.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600);
    return Chip(
      label: Text(label, style: labelStyle),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
