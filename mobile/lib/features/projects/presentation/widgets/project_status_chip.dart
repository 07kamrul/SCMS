import 'package:flutter/material.dart';

import '../../data/project_models.dart';

/// Small colored pill rendering a [ProjectStatus]'s label in its status
/// color — shared by [ProjectsListPage]/[MyProjectsPage] list tiles and
/// [ProjectMapPage]'s legend/info panel so status styling stays in one
/// place. Mirrors the `_Chip` pattern in
/// `features/tasks/presentation/tasks_list_page.dart`.
class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({super.key, required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
