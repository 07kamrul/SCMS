import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_token_storage.dart';
import 'api_exception.dart';
import 'envelope.dart';

/// Endpoints that never carry an access token — either because the caller
/// has no session yet (login, company registration) or because the request
/// itself carries the credential that replaces the access token (refresh).
const _noAuthPaths = <String>['/auth/login', '/auth/refresh', '/companies/register'];

/// Minimal internal mirror of the backend's `TokenPair` schema
/// (`app/schemas/auth.py`), used only to parse `/auth/refresh` responses.
/// Feature modules define their own richer auth models; this stays private
/// to keep the refresh plumbing self-contained.
class _TokenPair {
  const _TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory _TokenPair.fromJson(Map<String, dynamic> json) => _TokenPair(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    expiresIn: json['expires_in'] as int,
  );
}

/// Dio-based HTTP client for the SCFMS backend (`/api/v1`).
///
/// Handles:
/// - Attaching `Authorization: Bearer <access_token>` to every request
///   except the unauthenticated endpoints in [_noAuthPaths].
/// - Transparent access-token refresh on a 401 `token_expired` response:
///   the failed request is paused, a single `/auth/refresh` call is made
///   (concurrent 401s share the same in-flight refresh instead of each
///   firing their own), and on success the original request is retried
///   once with the new access token. On refresh failure (including
///   `token_reuse_detected`) stored tokens are cleared and
///   [onSessionExpired] is invoked so the app can force a logout.
/// - Decoding every response into the backend's `Envelope[T]` shape and
///   throwing [ApiException] for `success: false`, non-2xx status, or
///   network-level failures (timeout / no connectivity).
class ApiClient {
  ApiClient({
    required SecureTokenStorage tokenStorage,
    required String baseUrl,
    this.onSessionExpired,
  }) : _tokenStorage = tokenStorage,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
         ),
       ),
       _refreshDio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
         ),
       ) {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final SecureTokenStorage _tokenStorage;

  /// Invoked when a refresh fails (expired/reused refresh token) so the app
  /// can clear session state and navigate to the login screen.
  final void Function()? onSessionExpired;

  /// Main client used for all application requests.
  final Dio _dio;

  /// Separate client (no interceptors) used only for the `/auth/refresh`
  /// call itself, so refresh failures never re-trigger the refresh flow.
  final Dio _refreshDio;

  /// Non-null while a refresh is in flight; subsequent 401s await this
  /// same future instead of starting a second refresh call.
  Completer<bool>? _refreshCompleter;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_noAuthPaths.contains(options.path)) {
      final accessToken = await _tokenStorage.readAccessToken();
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final isTokenExpired =
        response != null &&
        response.statusCode == 401 &&
        _errorCodeOf(response) == 'token_expired';

    if (!isTokenExpired) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshTokens();
    if (!refreshed) {
      handler.next(err);
      return;
    }

    try {
      final requestOptions = err.requestOptions;
      final newAccessToken = await _tokenStorage.readAccessToken();
      if (newAccessToken != null) {
        requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      }
      final retryResponse = await _dio.fetch<dynamic>(requestOptions);
      handler.resolve(retryResponse);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  String? _errorCodeOf(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      return (data['error'] as Map<String, dynamic>)['code'] as String?;
    }
    return null;
  }

  /// Ensures only one `/auth/refresh` call is ever in flight; concurrent
  /// callers await the same [Completer].
  Future<bool> _refreshTokens() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    unawaited(
      _performRefresh()
          .then(completer.complete, onError: completer.completeError)
          .whenComplete(() => _refreshCompleter = null),
    );
    return completer.future;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      await _tokenStorage.clear();
      onSessionExpired?.call();
      return false;
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final body = response.data;
      if (body == null) {
        await _tokenStorage.clear();
        onSessionExpired?.call();
        return false;
      }
      final envelope = Envelope<_TokenPair>.fromJson(
        body,
        (json) => _TokenPair.fromJson(json as Map<String, dynamic>),
      );
      final tokens = envelope.data;
      if (!envelope.success || tokens == null) {
        await _tokenStorage.clear();
        onSessionExpired?.call();
        return false;
      }
      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return true;
    } on DioException {
      // Covers both transport failures and error responses (esp.
      // token_reuse_detected) — either way the session can no longer be
      // trusted, so force a full re-login.
      await _tokenStorage.clear();
      onSessionExpired?.call();
      return false;
    }
  }

  Future<Envelope<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromData,
  }) => _send(() => _dio.get<dynamic>(path, queryParameters: query), fromData);

  Future<Envelope<T>> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromData,
  }) => _send(() => _dio.post<dynamic>(path, data: body), fromData);

  Future<Envelope<T>> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromData,
  }) => _send(() => _dio.patch<dynamic>(path, data: body), fromData);

  Future<Envelope<T>> delete<T>(
    String path, {
    required T Function(Object? json) fromData,
  }) => _send(() => _dio.delete<dynamic>(path), fromData);

  Future<Envelope<T>> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Object? json) fromData,
  ) async {
    try {
      final response = await request();
      return _decode(response, fromData);
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) {
        throw ApiException.network(
          e.message ?? 'Could not reach the server.',
        );
      }
      throw _exceptionFromResponse(response);
    }
  }

  Envelope<T> _decode<T>(
    Response<dynamic> response,
    T Function(Object? json) fromData,
  ) {
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw ApiException.network('Received an unexpected response format.');
    }
    final envelope = Envelope<T>.fromJson(body, fromData);
    if (!envelope.success) {
      throw ApiException.fromEnvelopeError(
        response.statusCode ?? 0,
        envelope.error ??
            const ErrorDetail(code: 'unknown_error', message: 'Unknown error'),
      );
    }
    return envelope;
  }

  ApiException _exceptionFromResponse(Response<dynamic> response) {
    final body = response.data;
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      final error = ErrorDetail.fromJson(body['error'] as Map<String, dynamic>);
      return ApiException.fromEnvelopeError(response.statusCode ?? 0, error);
    }
    return ApiException(
      statusCode: response.statusCode ?? 0,
      errorCode: 'unknown_error',
      message: response.statusMessage ?? 'Request failed.',
    );
  }
}
