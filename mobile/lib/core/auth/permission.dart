/// Mirrors `backend/app/permissions/roles.py::Permission` exactly — same
/// enum members, same `resource:action` wire values. Feature modules gate
/// UI and navigation on these, checked via `role_permissions.dart`.
enum Permission {
  companyView('company:view'),
  companyManageSettings('company:manage_settings'),

  userView('user:view'),
  userCreate('user:create'),
  userUpdate('user:update'),
  userDeactivate('user:deactivate'),
  userResetPassword('user:reset_password'),
  userAssignRole('user:assign_role'),

  projectViewAll('project:view_all'),
  projectViewAssigned('project:view_assigned'),
  projectCreate('project:create'),
  projectUpdate('project:update'),
  projectArchive('project:archive'),
  projectDelete('project:delete'),

  assignmentView('assignment:view'),
  assignmentManage('assignment:manage'),

  trackingViewAll('tracking:view_all'),
  trackingViewAssigned('tracking:view_assigned'),
  trackingViewSelf('tracking:view_self'),
  locationShare('location:share'),

  taskCreate('task:create'),
  taskUpdate('task:update'),
  taskApprove('task:approve'),
  taskView('task:view'),

  issueCreate('issue:create'),
  issueUpdate('issue:update'),
  issueView('issue:view'),

  progressSubmit('progress:submit'),
  progressView('progress:view'),
  photoUpload('photo:upload'),

  dashboardCompany('dashboard:company'),
  reportsView('reports:view');

  const Permission(this.value);

  /// The `resource:action` string the backend sends/expects on the wire.
  final String value;

  static Permission fromWire(String value) {
    return Permission.values.firstWhere(
      (permission) => permission.value == value,
      orElse: () =>
          throw ArgumentError('Unknown permission wire value: $value'),
    );
  }
}

/// Mirrors `app/models/enums.py::Role` — the 5 fixed product roles.
enum Role {
  companyOwner('company_owner'),
  hrAdmin('hr_admin'),
  projectEngineer('project_engineer'),
  siteEngineer('site_engineer'),
  employee('employee');

  const Role(this.value);

  final String value;

  static Role fromWire(String value) {
    return Role.values.firstWhere(
      (role) => role.value == value,
      orElse: () => throw ArgumentError('Unknown role wire value: $value'),
    );
  }

  String toWire() => value;
}
