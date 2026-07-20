import 'envelope.dart';

/// Thrown by [ApiClient] whenever a request fails — either because the
/// backend returned `success: false` inside an [Envelope], the HTTP status
/// itself signalled an error, or the request never reached the server
/// (timeout / connectivity loss).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
    this.details,
  });

  /// HTTP status code, or `0` for network-level failures with no response.
  final int statusCode;

  /// Machine-readable error code from `error.code` (backend convention),
  /// or a synthetic code (e.g. `'network_error'`) for connectivity issues.
  final String errorCode;

  final String message;
  final Object? details;

  bool get isTokenExpired => errorCode == 'token_expired';

  bool get isTokenReuseDetected => errorCode == 'token_reuse_detected';

  bool get isAccountLocked =>
      errorCode == 'account_locked' || statusCode == 429;

  bool get isValidationError => errorCode == 'validation_error';

  bool get isPermissionDenied => errorCode == 'permission_denied';

  bool get isNotFound => errorCode == 'not_found';

  factory ApiException.fromEnvelopeError(int statusCode, ErrorDetail error) {
    return ApiException(
      statusCode: statusCode,
      errorCode: error.code,
      message: error.message,
      details: error.details,
    );
  }

  factory ApiException.network(String message) {
    return ApiException(
      statusCode: 0,
      errorCode: 'network_error',
      message: message,
    );
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, errorCode: $errorCode, message: $message)';
}
