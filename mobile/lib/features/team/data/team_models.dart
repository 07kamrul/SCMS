import 'package:mobile/core/auth/permission.dart';

/// Mirrors `backend/app/models/enums.py::UserStatus` exactly.
///
/// Kept local to this feature (rather than importing `auth`'s equivalent
/// enum) so `team` has no cross-feature dependency while other features are
/// being built in parallel — a small, intentional duplication.
enum UserStatus {
  active('active'),
  inactive('inactive'),
  suspended('suspended');

  const UserStatus(this.value);

  final String value;

  static UserStatus fromWire(String value) {
    return UserStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw ArgumentError('Unknown user status wire value: $value'),
    );
  }
}

/// Mirrors `backend/app/schemas/auth.py::UserPublic` / `app/schemas/user.py`.
///
/// Intentionally duplicates the `auth` feature's `UserPublic` shape — kept
/// local so this feature avoids a cross-feature dependency during parallel
/// development.
class TeamUser {
  const TeamUser({
    required this.id,
    required this.companyId,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    required this.status,
    this.profilePhotoUrl,
    this.jobTitle,
    required this.isIdentityVerified,
  });

  final String id;
  final String companyId;
  final String fullName;
  final String? email;
  final String? phone;
  final Role role;
  final UserStatus status;
  final String? profilePhotoUrl;
  final String? jobTitle;
  final bool isIdentityVerified;

  factory TeamUser.fromJson(Map<String, dynamic> json) {
    return TeamUser(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: Role.fromWire(json['role'] as String),
      status: UserStatus.fromWire(json['status'] as String),
      profilePhotoUrl: json['profile_photo_url'] as String?,
      jobTitle: json['job_title'] as String?,
      isIdentityVerified: json['is_identity_verified'] as bool,
    );
  }
}

/// Minimal project shape for the assignment-form project picker. Fetched
/// from `GET /projects` but deliberately kept to just `id`/`name` — this
/// avoids depending on the `projects` feature's richer models, which another
/// agent is building concurrently.
class ProjectSummary {
  const ProjectSummary({required this.id, required this.name});

  final String id;
  final String name;

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    return ProjectSummary(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

/// Mirrors `backend/app/models/enums.py::AssignmentRole` — the 3 roles a
/// user can hold on a specific project assignment (a subset of the 5
/// company-wide [Role]s).
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

  /// An assignment with no end date is the user's current, active one.
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
