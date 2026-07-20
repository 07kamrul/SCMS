import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/envelope.dart';

import 'issue_models.dart';

/// One page of issues plus the pagination metadata the backend returned,
/// so the list bloc can decide whether another page is available.
class IssueListPage {
  const IssueListPage({required this.items, required this.meta});

  final List<Issue> items;
  final PageMeta meta;
}

/// Repository for the issues feature. Wraps [ApiClient] calls against
/// `/issues/*` (`app/api/v1/issues.py`).
class IssueRepository {
  IssueRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Issue> create({
    required String projectId,
    required String title,
    String? description,
    required IssueCategory category,
    IssuePriority priority = IssuePriority.medium,
    String? assignedToUserId,
  }) async {
    final envelope = await _apiClient.post<Issue>(
      '/issues',
      body: {
        'project_id': projectId,
        'title': title,
        if (description != null) 'description': description,
        'category': category.value,
        'priority': priority.value,
        if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
      },
      fromData: (json) => Issue.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<IssueListPage> list({
    String? projectId,
    IssueStatus? status,
    IssuePriority? priority,
    IssueCategory? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    final envelope = await _apiClient.get<List<Issue>>(
      '/issues',
      query: {
        if (projectId != null) 'project_id': projectId,
        if (status != null) 'status': status.value,
        if (priority != null) 'priority': priority.value,
        if (category != null) 'category': category.value,
        'page': page,
        'page_size': pageSize,
      },
      fromData: (json) => listFromJson(json, Issue.fromJson),
    );
    return IssueListPage(items: envelope.data ?? const [], meta: envelope.meta!);
  }

  Future<Issue> getById(String id) async {
    final envelope = await _apiClient.get<Issue>(
      '/issues/$id',
      fromData: (json) => Issue.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<Issue> update(
    String id, {
    String? title,
    String? description,
    IssueCategory? category,
    IssuePriority? priority,
    IssueStatus? status,
    String? assignedToUserId,
    String? note,
  }) async {
    final envelope = await _apiClient.patch<Issue>(
      '/issues/$id',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (category != null) 'category': category.value,
        if (priority != null) 'priority': priority.value,
        if (status != null) 'status': status.value,
        if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
        if (note != null) 'note': note,
      },
      fromData: (json) => Issue.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<List<IssueStatusHistoryEntry>> history(String issueId) async {
    final envelope = await _apiClient.get<List<IssueStatusHistoryEntry>>(
      '/issues/$issueId/history',
      fromData: (json) => listFromJson(json, IssueStatusHistoryEntry.fromJson),
    );
    return envelope.data ?? const [];
  }

  Future<List<IssueComment>> listComments(String issueId) async {
    final envelope = await _apiClient.get<List<IssueComment>>(
      '/issues/$issueId/comments',
      fromData: (json) => listFromJson(json, IssueComment.fromJson),
    );
    return envelope.data ?? const [];
  }

  Future<IssueComment> addComment(String issueId, String body) async {
    final envelope = await _apiClient.post<IssueComment>(
      '/issues/$issueId/comments',
      body: {'body': body},
      fromData: (json) => IssueComment.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<List<IssuePhoto>> listPhotos(String issueId) async {
    final envelope = await _apiClient.get<List<IssuePhoto>>(
      '/issues/$issueId/photos',
      fromData: (json) => listFromJson(json, IssuePhoto.fromJson),
    );
    return envelope.data ?? const [];
  }

  Future<IssuePhoto> addPhoto(
    String issueId, {
    required String photoUrl,
    String? caption,
  }) async {
    final envelope = await _apiClient.post<IssuePhoto>(
      '/issues/$issueId/photos',
      body: {
        'photo_url': photoUrl,
        if (caption != null) 'caption': caption,
      },
      fromData: (json) => IssuePhoto.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
