import 'permission.dart';

/// Mirrors `backend/app/permissions/roles.py::ROLE_PERMISSIONS` exactly.
/// Keep this in lock-step with the backend matrix — it is the source of
/// truth for what each role can do, and this map must match it verbatim.
const Map<Role, Set<Permission>> rolePermissions = {
  // Company Owner: every permission that exists.
  Role.companyOwner: {
    Permission.companyView,
    Permission.companyManageSettings,
    Permission.userView,
    Permission.userCreate,
    Permission.userUpdate,
    Permission.userDeactivate,
    Permission.userResetPassword,
    Permission.userAssignRole,
    Permission.projectViewAll,
    Permission.projectViewAssigned,
    Permission.projectCreate,
    Permission.projectUpdate,
    Permission.projectArchive,
    Permission.projectDelete,
    Permission.assignmentView,
    Permission.assignmentManage,
    Permission.trackingViewAll,
    Permission.trackingViewAssigned,
    Permission.trackingViewSelf,
    Permission.locationShare,
    Permission.taskCreate,
    Permission.taskUpdate,
    Permission.taskApprove,
    Permission.taskView,
    Permission.issueCreate,
    Permission.issueUpdate,
    Permission.issueView,
    Permission.progressSubmit,
    Permission.progressView,
    Permission.photoUpload,
    Permission.dashboardCompany,
    Permission.reportsView,
  },

  Role.hrAdmin: {
    Permission.companyView,
    Permission.userView,
    Permission.userCreate,
    Permission.userUpdate,
    Permission.userDeactivate,
    Permission.userResetPassword,
    Permission.userAssignRole,
    Permission.projectViewAll,
    Permission.assignmentView,
    Permission.assignmentManage,
    Permission.trackingViewAssigned,
    Permission.reportsView,
  },

  Role.projectEngineer: {
    Permission.companyView,
    Permission.userView,
    Permission.projectViewAssigned,
    Permission.assignmentView,
    Permission.taskCreate,
    Permission.taskUpdate,
    Permission.taskApprove,
    Permission.issueCreate,
    Permission.issueUpdate,
    Permission.progressView,
    Permission.reportsView,
    // _MANAGER_TRACKING
    Permission.trackingViewAssigned,
    Permission.trackingViewSelf,
    // _FIELD_CONTENT
    Permission.taskView,
    Permission.issueView,
    Permission.photoUpload,
  },

  Role.siteEngineer: {
    Permission.companyView,
    Permission.userView,
    Permission.projectViewAssigned,
    Permission.assignmentView,
    Permission.taskCreate,
    Permission.taskUpdate,
    Permission.issueCreate,
    Permission.issueUpdate,
    Permission.progressSubmit,
    // _MANAGER_TRACKING
    Permission.trackingViewAssigned,
    Permission.trackingViewSelf,
    // _FIELD_CONTENT
    Permission.taskView,
    Permission.issueView,
    Permission.progressView,
    Permission.photoUpload,
  },

  Role.employee: {
    Permission.projectViewAssigned,
    Permission.trackingViewSelf,
    Permission.locationShare,
    Permission.taskView,
    Permission.taskUpdate,
    Permission.issueCreate,
    Permission.issueView,
    Permission.photoUpload,
  },
};

bool hasPermission(Role role, Permission permission) =>
    rolePermissions[role]?.contains(permission) ?? false;
