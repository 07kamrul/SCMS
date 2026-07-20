import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Persists the access/refresh token pair in the platform secure store
/// (Android EncryptedSharedPreferences / Keystore-backed). Everything that
/// needs the current tokens (the [ApiClient] auth interceptor, session
/// bootstrap on app start, logout) goes through this single class rather
/// than touching `FlutterSecureStorage` directly.
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'scfms_access_token';
  static const _refreshTokenKey = 'scfms_refresh_token';

  /// Stable per-install identifier used as the push device token placeholder
  /// until real APNs/FCM token plumbing lands (see
  /// `features/notifications/data/notification_repository.dart::registerDeviceToken`).
  /// Generated once with `uuid` (never `Object().hashCode`-style fallbacks,
  /// which are not stable/unique enough) and persisted so it survives app
  /// restarts.
  static const _deviceIdKey = 'scfms_device_id';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  /// Returns the persisted device id, generating and persisting one on
  /// first call. Stable across app restarts (survives until the app is
  /// uninstalled or secure storage is cleared) — intentionally NOT cleared
  /// by [clear], since it identifies the device/install, not the session.
  Future<String> readOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null) return existing;
    final generated = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }
}
