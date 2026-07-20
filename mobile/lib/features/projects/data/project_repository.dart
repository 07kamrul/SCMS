import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/envelope.dart';

import 'assignment_models.dart';
import 'project_models.dart';

/// Repository for the projects feature. Wraps [ApiClient] calls against
/// `/projects/*` and `/assignments/me`.
class ProjectRepository {
  ProjectRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<({List<Project> projects, int total})> list({
    int page = 1,
    int pageSize = 20,
    ProjectStatus? status,
    String? search,
  }) async {
    final envelope = await _apiClient.get<List<Project>>(
      '/projects',
      query: {
        'page': page,
        'page_size': pageSize,
        if (status != null) 'status': status.toWire(),
        if (search != null) 'search': search,
      },
      fromData: (json) => listFromJson(json, Project.fromJson),
    );
    return (
      projects: envelope.data ?? const <Project>[],
      total: envelope.meta?.total ?? 0,
    );
  }

  /// All projects the caller can see, unpaginated — used for map rendering
  /// and for cross-referencing against `/assignments/me`.
  Future<List<Project>> listForMap() async {
    final envelope = await _apiClient.get<List<Project>>(
      '/projects/map',
      fromData: (json) => listFromJson(json, Project.fromJson),
    );
    return envelope.data ?? const <Project>[];
  }

  Future<Project> getById(String id) async {
    final envelope = await _apiClient.get<Project>(
      '/projects/$id',
      fromData: (json) => Project.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<Project> create({
    required String name,
    String? description,
    ProjectStatus status = ProjectStatus.planned,
    GeoJsonPolygon? boundary,
  }) async {
    final envelope = await _apiClient.post<Project>(
      '/projects',
      body: {
        'name': name,
        if (description != null) 'description': description,
        'status': status.toWire(),
        if (boundary != null) 'boundary': boundary.toJson(),
      },
      fromData: (json) => Project.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// Only non-null fields are sent, so omitting e.g. [boundary] on an update
  /// leaves the project's existing boundary unchanged server-side.
  Future<Project> update(
    String id, {
    String? name,
    String? description,
    ProjectStatus? status,
    int? progressPercent,
    GeoJsonPolygon? boundary,
  }) async {
    final envelope = await _apiClient.patch<Project>(
      '/projects/$id',
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (status != null) 'status': status.toWire(),
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (boundary != null) 'boundary': boundary.toJson(),
      },
      fromData: (json) => Project.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<Project> archive(String id) async {
    final envelope = await _apiClient.post<Project>(
      '/projects/$id/archive',
      fromData: (json) => Project.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<void> delete(String id) async {
    await _apiClient.delete<Map<String, dynamic>>(
      '/projects/$id',
      fromData: (json) => json as Map<String, dynamic>,
    );
  }

  /// Full assignment history (active + ended) for the logged-in user.
  Future<List<Assignment>> myAssignments() async {
    final envelope = await _apiClient.get<List<Assignment>>(
      '/assignments/me',
      fromData: (json) => listFromJson(json, Assignment.fromJson),
    );
    return envelope.data ?? const <Assignment>[];
  }
}
