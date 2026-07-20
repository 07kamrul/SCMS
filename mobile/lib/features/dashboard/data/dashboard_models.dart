import 'package:mobile/core/auth/permission.dart';

/// Mirrors `backend/app/schemas/dashboard.py::DashboardSummary` exactly.
/// `pendingTaskApprovals` is only populated for roles that hold
/// `TASK_APPROVE` (Project Engineer); `teamStatusCounts` is only populated
/// for roles that can view team tracking (Owner/HR/PE/SE).
class DashboardSummary {
  const DashboardSummary({
    required this.role,
    required this.myOpenTasks,
    required this.myOverdueTasks,
    required this.myOpenIssues,
    required this.visibleProjectCount,
    required this.unreadNotifications,
    this.pendingTaskApprovals,
    this.teamStatusCounts,
  });

  final Role role;
  final int myOpenTasks;
  final int myOverdueTasks;
  final int myOpenIssues;
  final int visibleProjectCount;
  final int unreadNotifications;
  final int? pendingTaskApprovals;

  /// Keyed by `LocationStatus` wire value (see
  /// `app/models/enums.py::LocationStatus`); `null` when the current role
  /// cannot view team tracking.
  final Map<String, int>? teamStatusCounts;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final rawTeamStatusCounts = json['team_status_counts'];
    return DashboardSummary(
      role: Role.fromWire(json['role'] as String),
      myOpenTasks: json['my_open_tasks'] as int,
      myOverdueTasks: json['my_overdue_tasks'] as int,
      myOpenIssues: json['my_open_issues'] as int,
      visibleProjectCount: json['visible_project_count'] as int,
      unreadNotifications: json['unread_notifications'] as int,
      pendingTaskApprovals: json['pending_task_approvals'] as int?,
      teamStatusCounts: rawTeamStatusCounts == null
          ? null
          : (rawTeamStatusCounts as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value as int),
            ),
    );
  }
}
