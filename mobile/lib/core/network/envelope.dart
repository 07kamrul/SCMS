/// Dart mirror of the backend's `Envelope[T]` wire format
/// (`app/schemas/common.py`). Every API response, success or error, is
/// wrapped exactly like this:
///
/// ```json
/// {"success": true, "data": {...}|[...]|null, "error": {"code": str, "message": str, "details": any|null}|null, "meta": {"total": int, "page": int, "page_size": int, "total_pages": int}|null}
/// ```
library;

/// Pagination metadata attached to list responses.
class PageMeta {
  const PageMeta({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory PageMeta.fromJson(Map<String, dynamic> json) {
    return PageMeta(
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalPages: json['total_pages'] as int,
    );
  }
}

/// Structured error payload returned when `success == false`.
class ErrorDetail {
  const ErrorDetail({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  factory ErrorDetail.fromJson(Map<String, dynamic> json) {
    return ErrorDetail(
      code: json['code'] as String,
      message: json['message'] as String,
      details: json['details'],
    );
  }
}

/// Generic response envelope. `fromData` decodes the raw `data` field
/// (which may be a `Map`, a `List`, or `null`) into `T`.
class Envelope<T> {
  const Envelope({
    required this.success,
    required this.data,
    required this.error,
    required this.meta,
  });

  final bool success;
  final T? data;
  final ErrorDetail? error;
  final PageMeta? meta;

  factory Envelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromData,
  ) {
    final rawData = json['data'];
    return Envelope<T>(
      success: json['success'] as bool? ?? false,
      data: rawData == null ? null : fromData(rawData),
      error: json['error'] == null
          ? null
          : ErrorDetail.fromJson(json['error'] as Map<String, dynamic>),
      meta: json['meta'] == null
          ? null
          : PageMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }
}

/// Decodes a JSON array (the raw `data` field of a list-typed envelope)
/// into a `List<T>` using the given per-item decoder.
List<T> listFromJson<T>(
  Object? json,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (json == null) return <T>[];
  return (json as List<dynamic>)
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList();
}
