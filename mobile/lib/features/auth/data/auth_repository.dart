import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/secure_token_storage.dart';

import 'auth_models.dart';

/// Repository for the auth feature. Wraps [ApiClient] calls against
/// `/auth/*` and `/companies/register`, and keeps [SecureTokenStorage] in
/// sync with the session lifecycle (login persists tokens, logout always
/// clears them).
class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;

  Future<LoginResponse> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final envelope = await _apiClient.post<LoginResponse>(
      '/auth/login',
      body: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      },
      fromData: (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
    );
    final loginResponse = envelope.data!;
    await _tokenStorage.saveTokens(
      accessToken: loginResponse.tokens.accessToken,
      refreshToken: loginResponse.tokens.refreshToken,
    );
    return loginResponse;
  }

  Future<void> registerCompany({
    required String companyName,
    required String ownerFullName,
    String? ownerEmail,
    String? ownerPhone,
    required String ownerPassword,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/companies/register',
      body: {
        'company_name': companyName,
        'owner_full_name': ownerFullName,
        if (ownerEmail != null) 'owner_email': ownerEmail,
        if (ownerPhone != null) 'owner_phone': ownerPhone,
        'owner_password': ownerPassword,
      },
      fromData: (json) => json as Map<String, dynamic>,
    );
  }

  Future<UserPublic> fetchMe() async {
    final envelope = await _apiClient.get<UserPublic>(
      '/auth/me',
      fromData: (json) => UserPublic.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/auth/change-password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
      fromData: (json) => json as Map<String, dynamic>,
    );
  }

  /// Always clears the local session, even if the network call fails —
  /// a failed logout request must never leave the user stuck "logged in"
  /// on this device, and callers can always assume this completes without
  /// throwing.
  Future<void> logout() async {
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken != null) {
        await _apiClient.post<Map<String, dynamic>>(
          '/auth/logout',
          body: {'refresh_token': refreshToken},
          fromData: (json) => json as Map<String, dynamic>,
        );
      }
    } on ApiException {
      // Best-effort revocation: the server-side refresh token may already
      // be gone, or the network may be unreachable — either way the local
      // session must still be cleared below.
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<bool> hasSession() async {
    final accessToken = await _tokenStorage.readAccessToken();
    return accessToken != null;
  }
}
