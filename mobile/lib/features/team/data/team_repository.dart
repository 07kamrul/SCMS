import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/envelope.dart';

import 'team_models.dart';

/// A page of users plus the pagination metadata the backend returned.
class UserPage {
  const UserPage({required this.users, required this.meta});

  final List<TeamUser> users;
  final PageMeta? meta;
}

/// A page of assignments plus the pagination metadata the backend returned.
class AssignmentPage {
  const AssignmentPage({required this.assignments, required this.meta});

  final List<Assignment> assignments;
  final PageMeta? meta;
}

/// Repository for the `team` feature: user management (`/users`) and
/// project assignments (`/assignments`), plus a minimal project lookup
/// (`/projects`) for the assignment-form picker.
class TeamRepository {
  TeamRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserPage> listUsers({
    int page = 1,
    int pageSize = 20,
    Role? role,
    String? search,
  }) async {
    final envelope = await _apiClient.get<List<TeamUser>>(
      '/users',
      query: {
        'page': page,
        'page_size': pageSize,
        if (role != null) 'role': role.toWire(),
        if (search != null && search.isNotEmpty) 'search': search,
      },
      fromData: (json) => listFromJson(json, TeamUser.fromJson),
    );
    return UserPage(users: envelope.data ?? const [], meta: envelope.meta);
  }

  Future<TeamUser> createUser({
    required String fullName,
    String? email,
    String? phone,
    required String password,
    required Role role,
    String? jobTitle,
  }) async {
    final envelope = await _apiClient.post<TeamUser>(
      '/users',
      body: {
        'full_name': fullName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
        'role': role.toWire(),
        if (jobTitle != null) 'job_title': jobTitle,
      },
      fromData: (json) => TeamUser.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<TeamUser> getUser(String userId) async {
    final envelope = await _apiClient.get<TeamUser>(
      '/users/$userId',
      fromData: (json) => TeamUser.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// Only non-null fields are sent — matches `UserUpdate`'s all-optional
  /// shape on the backend (`app/schemas/user.py`).
  Future<TeamUser> updateUser(
    String userId, {
    String? fullName,
    String? email,
    String? phone,
    Role? role,
    UserStatus? status,
    String? jobTitle,
    bool? isIdentityVerified,
    String? profilePhotoUrl,
  }) async {
    final envelope = await _apiClient.patch<TeamUser>(
      '/users/$userId',
      body: {
        if (fullName != null) 'full_name': fullName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (role != null) 'role': role.toWire(),
        if (status != null) 'status': status.value,
        if (jobTitle != null) 'job_title': jobTitle,
        if (isIdentityVerified != null) 'is_identity_verified': isIdentityVerified,
        if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
      },
      fromData: (json) => TeamUser.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<TeamUser> deactivateUser(String userId) async {
    final envelope = await _apiClient.post<TeamUser>(
      '/users/$userId/deactivate',
      fromData: (json) => TeamUser.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<TeamUser> activateUser(String userId) async {
    final envelope = await _apiClient.post<TeamUser>(
      '/users/$userId/activate',
      fromData: (json) => TeamUser.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// The backend takes `new_password` as a query parameter, not a JSON body
  /// (`POST /users/{id}/reset-password?new_password=...`) — [ApiClient.post]
  /// only supports a body, so the query string is built and appended here.
  /// Returns the backend's confirmation message.
  Future<String> resetPassword(String userId, String newPassword) async {
    final query = Uri(queryParameters: {'new_password': newPassword}).query;
    final envelope = await _apiClient.post<Map<String, dynamic>>(
      '/users/$userId/reset-password?$query',
      fromData: (json) => json as Map<String, dynamic>,
    );
    return envelope.data!['detail'] as String? ?? 'Password reset.';
  }

  /// `GET /projects`, trimmed to just `id`/`name` for the assignment-form
  /// picker. Requests a large page so the dropdown has the full roster in
  /// one call for typical company sizes.
  Future<List<ProjectSummary>> listProjectsForPicker() async {
    final envelope = await _apiClient.get<List<ProjectSummary>>(
      '/projects',
      query: {'page': 1, 'page_size': 100},
      fromData: (json) => listFromJson(json, ProjectSummary.fromJson),
    );
    return envelope.data ?? const [];
  }

  Future<Assignment> createAssignment({
    required String projectId,
    required String userId,
    required AssignmentRole role,
  }) async {
    final envelope = await _apiClient.post<Assignment>(
      '/assignments',
      body: {
        'project_id': projectId,
        'user_id': userId,
        'role': role.value,
      },
      fromData: (json) => Assignment.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<Assignment> endAssignment(String assignmentId) async {
    final envelope = await _apiClient.post<Assignment>(
      '/assignments/$assignmentId/end',
      fromData: (json) => Assignment.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<Assignment> transferAssignment(
    String assignmentId, {
    required String newProjectId,
    required AssignmentRole role,
  }) async {
    final envelope = await _apiClient.post<Assignment>(
      '/assignments/$assignmentId/transfer',
      body: {'new_project_id': newProjectId, 'role': role.value},
      fromData: (json) => Assignment.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<AssignmentPage> listAssignments({
    String? projectId,
    String? userId,
    int page = 1,
    int pageSize = 100,
  }) async {
    final envelope = await _apiClient.get<List<Assignment>>(
      '/assignments',
      query: {
        'page': page,
        'page_size': pageSize,
        if (projectId != null) 'project_id': projectId,
        if (userId != null) 'user_id': userId,
      },
      fromData: (json) => listFromJson(json, Assignment.fromJson),
    );
    return AssignmentPage(
      assignments: envelope.data ?? const [],
      meta: envelope.meta,
    );
  }
}
