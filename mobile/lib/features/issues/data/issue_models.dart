import 'package:flutter/material.dart';

/// Mirrors `backend/app/models/enums.py::IssueStatus` exactly.
enum IssueStatus {
  open('open', 'Open', Colors.red),
  assigned('assigned', 'Assigned', Colors.orange),
  inProgress('in_progress', 'In progress', Colors.blue),
  waiting('waiting', 'Waiting', Colors.amber),
  resolved('resolved', 'Resolved', Colors.teal),
  closed('closed', 'Closed', Colors.green),
  reopened('reopened', 'Reopened', Colors.deepOrange);

  const IssueStatus(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static IssueStatus fromWire(String value) {
    return IssueStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw ArgumentError('Unknown issue status wire value: $value'),
    );
  }
}

/// Mirrors `backend/app/models/enums.py::IssuePriority` exactly.
enum IssuePriority {
  low('low', 'Low', Colors.grey),
  medium('medium', 'Medium', Colors.blue),
  high('high', 'High', Colors.orange),
  critical('critical', 'Critical', Colors.red);

  const IssuePriority(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static IssuePriority fromWire(String value) {
    return IssuePriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => throw ArgumentError('Unknown issue priority wire value: $value'),
    );
  }
}

/// Mirrors `backend/app/models/enums.py::IssueCategory` exactly.
enum IssueCategory {
  workDelay('work_delay', 'Work delay'),
  designProblem('design_problem', 'Design problem'),
  workerShortage('worker_shortage', 'Worker shortage'),
  siteAccessProblem('site_access_problem', 'Site access problem'),
  clientChange('client_change', 'Client change'),
  weather('weather', 'Weather'),
  qualityProblem('quality_problem', 'Quality problem'),
  utilityProblem('utility_problem', 'Utility problem'),
  approvalProblem('approval_problem', 'Approval problem'),
  other('other', 'Other');

  const IssueCategory(this.value, this.label);

  final String value;
  final String label;

  static IssueCategory fromWire(String value) {
    return IssueCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => throw ArgumentError('Unknown issue category wire value: $value'),
    );
  }
}

/// Mirrors `backend/app/schemas/issue.py::IssuePublic`.
class Issue {
  const Issue({
    required this.id,
    required this.companyId,
    required this.projectId,
    this.reportedByUserId,
    this.assignedToUserId,
    required this.title,
    this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String? reportedByUserId;
  final String? assignedToUserId;
  final String title;
  final String? description;
  final IssueCategory category;
  final IssuePriority priority;
  final IssueStatus status;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      reportedByUserId: json['reported_by_user_id'] as String?,
      assignedToUserId: json['assigned_to_user_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: IssueCategory.fromWire(json['category'] as String),
      priority: IssuePriority.fromWire(json['priority'] as String),
      status: IssueStatus.fromWire(json['status'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Mirrors `backend/app/schemas/issue.py::IssueStatusHistoryPublic`.
class IssueStatusHistoryEntry {
  const IssueStatusHistoryEntry({
    required this.id,
    required this.issueId,
    this.fromStatus,
    required this.toStatus,
    this.changedByUserId,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String issueId;
  final IssueStatus? fromStatus;
  final IssueStatus toStatus;
  final String? changedByUserId;
  final String? note;
  final DateTime createdAt;

  factory IssueStatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return IssueStatusHistoryEntry(
      id: json['id'] as String,
      issueId: json['issue_id'] as String,
      fromStatus: json['from_status'] == null
          ? null
          : IssueStatus.fromWire(json['from_status'] as String),
      toStatus: IssueStatus.fromWire(json['to_status'] as String),
      changedByUserId: json['changed_by_user_id'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Mirrors `backend/app/schemas/issue.py::IssueCommentPublic`.
class IssueComment {
  const IssueComment({
    required this.id,
    required this.issueId,
    this.userId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String issueId;
  final String? userId;
  final String body;
  final DateTime createdAt;

  factory IssueComment.fromJson(Map<String, dynamic> json) {
    return IssueComment(
      id: json['id'] as String,
      issueId: json['issue_id'] as String,
      userId: json['user_id'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Mirrors `backend/app/schemas/issue.py::IssuePhotoPublic`.
class IssuePhoto {
  const IssuePhoto({
    required this.id,
    required this.issueId,
    this.userId,
    required this.photoUrl,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String issueId;
  final String? userId;
  final String photoUrl;
  final String? caption;
  final DateTime createdAt;

  factory IssuePhoto.fromJson(Map<String, dynamic> json) {
    return IssuePhoto(
      id: json['id'] as String,
      issueId: json['issue_id'] as String,
      userId: json['user_id'] as String?,
      photoUrl: json['photo_url'] as String,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
