/// Mirrors `backend/app/models/enums.py::AssignmentRole` exactly.
enum AssignmentRole {
  projectEngineer('project_engineer'),
  siteEngineer('site_engineer'),
  employee('employee');

  const AssignmentRole(this.value);

  final String value;

  static AssignmentRole fromWire(String value) {
    return AssignmentRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () =>
          throw ArgumentError('Unknown assignment role wire value: $value'),
    );
  }

  String toWire() => value;
}

/// Mirrors `backend/app/schemas/assignment.py::AssignmentPublic`.
class Assignment {
  const Assignment({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.userId,
    this.assignedByUserId,
    required this.role,
    required this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String userId;
  final String? assignedByUserId;
  final AssignmentRole role;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// An assignment with no end date is the user's current, active
  /// assignment; ended assignments remain only as history.
  bool get isActive => endedAt == null;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      userId: json['user_id'] as String,
      assignedByUserId: json['assigned_by_user_id'] as String?,
      role: AssignmentRole.fromWire(json['role'] as String),
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
