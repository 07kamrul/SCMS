import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import 'notification_models.dart';

/// Repository for the notifications feature. Wraps [ApiClient] calls
/// against `/notifications/*` (list mine, mark read, register a push
/// device token).
class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Returns the page of notifications matching the given filters, plus the
  /// total count across all pages (from the response's pagination `meta`).
  Future<(List<AppNotification>, int)> listMine({
    bool unreadOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final envelope = await _apiClient.get<List<AppNotification>>(
      '/notifications',
      query: {
        'unread_only': unreadOnly.toString(),
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
      fromData: (json) => listFromJson(json, AppNotification.fromJson),
    );
    return (envelope.data ?? const <AppNotification>[], envelope.meta?.total ?? 0);
  }

  Future<AppNotification> markRead(String id) async {
    final envelope = await _apiClient.post<AppNotification>(
      '/notifications/$id/read',
      fromData: (json) =>
          AppNotification.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// `platform` is the wire value (`"android"`/`"ios"`) — see
  /// `DevicePlatform`.
  Future<DeviceToken> registerDeviceToken({
    required String platform,
    required String token,
  }) async {
    final envelope = await _apiClient.post<DeviceToken>(
      '/notifications/device-tokens',
      body: {'platform': platform, 'token': token},
      fromData: (json) => DeviceToken.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
