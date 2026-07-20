import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists whether this device has locally recorded that the user granted
/// location-tracking consent (`POST /locations/consent`).
///
/// The backend has no `GET` endpoint to check consent status — only the
/// `POST /locations/consent` action, which is itself idempotent (always
/// re-stamps `location_consent_at` to "now" and succeeds). So the app is the
/// source of truth for "have we already shown/granted the consent gate on
/// this device", stored here rather than in `data/` (which belongs to the
/// location-repository/offline-retry work happening in parallel).
class LocationConsentStorage {
  LocationConsentStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _consentedAtKey = 'scfms_location_consented_at';

  Future<DateTime?> readConsentedAt() async {
    final raw = await _storage.read(key: _consentedAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveConsentedAt(DateTime consentedAt) {
    return _storage.write(
      key: _consentedAtKey,
      value: consentedAt.toUtc().toIso8601String(),
    );
  }

  Future<void> clear() => _storage.delete(key: _consentedAtKey);
}
