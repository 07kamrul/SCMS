import 'package:flutter/material.dart';

/// Mirrors `backend/app/models/enums.py::TaskStatus` exactly.
enum TaskStatus {
  todo('todo', 'To Do', Colors.grey),
  inProgress('in_progress', 'In Progress', Colors.blue),
  blocked('blocked', 'Blocked', Colors.red),
  submitted('submitted', 'Submitted', Colors.amber),
  approved('approved', 'Approved', Colors.teal),
  rejected('rejected', 'Rejected', Colors.deepOrange),
  completed('completed', 'Completed', Colors.green),
  cancelled('cancelled', 'Cancelled', Colors.blueGrey);

  const TaskStatus(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static TaskStatus fromWire(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw ArgumentError('Unknown task status wire value: $value'),
    );
  }
}

/// Mirrors `backend/app/models/enums.py::TaskPriority` exactly.
enum TaskPriority {
  low('low', 'Low', Colors.grey),
  medium('medium', 'Medium', Colors.blue),
  high('high', 'High', Colors.orange),
  urgent('urgent', 'Urgent', Colors.red);

  const TaskPriority(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static TaskPriority fromWire(String value) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () =>
          throw ArgumentError('Unknown task priority wire value: $value'),
    );
  }
}

/// Mirrors `backend/app/schemas/task.py::TaskPublic`. `isOverdue` is
/// server-computed (`computed_field`) — parsed as-is, never recomputed here.
class Task {
  const Task({
    required this.id,
    required this.companyId,
    required this.projectId,
    this.assignedToUserId,
    this.createdByUserId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.isOverdue,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String? assignedToUserId;
  final String? createdByUserId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOverdue;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      assignedToUserId: json['assigned_to_user_id'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.fromWire(json['status'] as String),
      priority: TaskPriority.fromWire(json['priority'] as String),
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isOverdue: json['is_overdue'] as bool,
    );
  }
}

/// Mirrors `backend/app/schemas/task.py::TaskCommentPublic`. Append-only.
class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    this.userId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String? userId;
  final String body;
  final DateTime createdAt;

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    return TaskComment(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      userId: json['user_id'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Mirrors `backend/app/schemas/task.py::TaskPhotoPublic`.
class TaskPhoto {
  const TaskPhoto({
    required this.id,
    required this.taskId,
    this.userId,
    required this.photoUrl,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String? userId;
  final String photoUrl;
  final String? caption;
  final DateTime createdAt;

  factory TaskPhoto.fromJson(Map<String, dynamic> json) {
    return TaskPhoto(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      userId: json['user_id'] as String?,
      photoUrl: json['photo_url'] as String,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
