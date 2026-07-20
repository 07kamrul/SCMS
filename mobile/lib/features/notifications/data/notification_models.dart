/// Mirrors `backend/app/models/enums.py::DevicePlatform` exactly.
enum DevicePlatform {
  android('android'),
  ios('ios');

  const DevicePlatform(this.value);

  final String value;

  static DevicePlatform fromWire(String value) {
    return DevicePlatform.values.firstWhere(
      (platform) => platform.value == value,
      orElse: () =>
          throw ArgumentError('Unknown device platform wire value: $value'),
    );
  }
}

/// Mirrors `backend/app/schemas/notification.py::NotificationPublic` exactly.
/// Named `AppNotification` (not `Notification`) to avoid colliding with
/// `dart:ui`'s `Notification`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data,
    this.entityId,
    this.readAt,
    required this.createdAt,
  });

  final String id;

  /// e.g. `"task.assigned"`, `"task.status_changed"`, `"issue.created"`,
  /// `"issue.status_changed"` — drives notification-tap routing.
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final String? entityId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      entityId: json['entity_id'] as String?,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Mirrors `backend/app/schemas/notification.py::DeviceTokenPublic` exactly.
class DeviceToken {
  const DeviceToken({
    required this.id,
    required this.platform,
    required this.lastSeenAt,
  });

  final String id;
  final DevicePlatform platform;
  final DateTime lastSeenAt;

  factory DeviceToken.fromJson(Map<String, dynamic> json) {
    return DeviceToken(
      id: json['id'] as String,
      platform: DevicePlatform.fromWire(json['platform'] as String),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    );
  }
}
