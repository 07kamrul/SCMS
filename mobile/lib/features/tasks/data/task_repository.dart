import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import 'task_models.dart';

/// Repository for the tasks feature. Wraps [ApiClient] calls against
/// `/tasks/*` (create/list/get/update, comments, photos).
class TaskRepository {
  TaskRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Task> create({
    required String projectId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    String? assignedToUserId,
    DateTime? dueDate,
  }) async {
    final envelope = await _apiClient.post<Task>(
      '/tasks',
      body: {
        'project_id': projectId,
        'title': title,
        if (description != null) 'description': description,
        'priority': priority.value,
        if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
        if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
      },
      fromData: (json) => Task.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// Returns the page of tasks matching the given filters, plus the total
  /// count across all pages (from the response's pagination `meta`).
  Future<(List<Task>, int)> list({
    String? projectId,
    TaskStatus? status,
    TaskPriority? priority,
    bool overdue = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final envelope = await _apiClient.get<List<Task>>(
      '/tasks',
      query: {
        if (projectId != null) 'project_id': projectId,
        if (status != null) 'status': status.value,
        if (priority != null) 'priority': priority.value,
        'overdue': overdue.toString(),
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
      fromData: (json) => listFromJson(json, Task.fromJson),
    );
    return (envelope.data ?? const <Task>[], envelope.meta?.total ?? 0);
  }

  Future<Task> getById(String id) async {
    final envelope = await _apiClient.get<Task>(
      '/tasks/$id',
      fromData: (json) => Task.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// `null` fields are left unchanged server-side. A permission-denied
  /// failure (e.g. attempting to set `approved`/`rejected`/`completed` or
  /// reassign without the right role) surfaces as an [ApiException] with
  /// `isPermissionDenied == true` — callers should show `e.message` as-is.
  Future<Task> update(
    String id, {
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    String? assignedToUserId,
    DateTime? dueDate,
  }) async {
    final envelope = await _apiClient.patch<Task>(
      '/tasks/$id',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (status != null) 'status': status.value,
        if (priority != null) 'priority': priority.value,
        if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
        if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
      },
      fromData: (json) => Task.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<List<TaskComment>> listComments(String taskId) async {
    final envelope = await _apiClient.get<List<TaskComment>>(
      '/tasks/$taskId/comments',
      fromData: (json) => listFromJson(json, TaskComment.fromJson),
    );
    return envelope.data ?? const <TaskComment>[];
  }

  Future<TaskComment> addComment(String taskId, String body) async {
    final envelope = await _apiClient.post<TaskComment>(
      '/tasks/$taskId/comments',
      body: {'body': body},
      fromData: (json) => TaskComment.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<List<TaskPhoto>> listPhotos(String taskId) async {
    final envelope = await _apiClient.get<List<TaskPhoto>>(
      '/tasks/$taskId/photos',
      fromData: (json) => listFromJson(json, TaskPhoto.fromJson),
    );
    return envelope.data ?? const <TaskPhoto>[];
  }

  Future<TaskPhoto> addPhoto(
    String taskId, {
    required String photoUrl,
    String? caption,
  }) async {
    final envelope = await _apiClient.post<TaskPhoto>(
      '/tasks/$taskId/photos',
      body: {
        'photo_url': photoUrl,
        if (caption != null) 'caption': caption,
      },
      fromData: (json) => TaskPhoto.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
