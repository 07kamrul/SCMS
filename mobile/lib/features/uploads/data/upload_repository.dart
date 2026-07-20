import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_queue_repository.dart';

/// Matches the backend's `UploadEntityType` (`app/utils/storage.py`).
enum UploadEntityType {
  task('task'),
  issue('issue'),
  progress('progress');

  const UploadEntityType(this.value);
  final String value;

  /// Inverse of [value] — used when replaying a queued upload, whose
  /// `entity_type` column was stored as this wire string.
  static UploadEntityType fromValue(String value) {
    return UploadEntityType.values.firstWhere(
      (entityType) => entityType.value == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Unknown UploadEntityType wire value',
      ),
    );
  }
}

/// Thrown by [UploadRepository.captureUploadAndAttach] when a *network*
/// failure (no response reached the server) occurs at any step of
/// presign/PUT/attach — the original file has already been queued via
/// `OfflineQueueRepository.enqueuePhotoUpload` for a later retry by
/// `PhotoUploadRetryService`. Callers should catch this specifically and
/// show a "will sync later" message rather than a hard error.
class PhotoUploadQueuedException implements Exception {
  const PhotoUploadQueuedException();

  @override
  String toString() =>
      'PhotoUploadQueuedException: no connection — queued for retry once back online.';
}

class _PresignResult {
  const _PresignResult({
    required this.uploadUrl,
    required this.photoUrl,
  });

  final String uploadUrl;
  final String photoUrl;

  factory _PresignResult.fromJson(Map<String, dynamic> json) => _PresignResult(
    uploadUrl: json['upload_url'] as String,
    photoUrl: json['photo_url'] as String,
  );
}

/// Photo capture + compress + presigned-upload flow shared by tasks, issues,
/// and progress reports. Those endpoints only accept `{photo_url, caption}`
/// JSON, so the actual bytes go straight to MinIO via a short-lived presigned
/// PUT URL obtained from `POST /uploads/presign` — the app never holds S3
/// credentials.
class UploadRepository {
  UploadRepository(
    this._apiClient, {
    ImagePicker? picker,
    Dio? rawDio,
    OfflineQueueRepository? queueRepository,
  }) : _picker = picker ?? ImagePicker(),
       _rawDio = rawDio ?? Dio(),
       _queueRepository = queueRepository ?? OfflineQueueRepository();

  final ApiClient _apiClient;
  final ImagePicker _picker;

  /// Plain Dio instance (no auth interceptor, no base URL) used only for the
  /// raw `PUT` of file bytes to the presigned MinIO URL.
  final Dio _rawDio;

  final OfflineQueueRepository _queueRepository;

  static const _jpegQuality = 70;
  static const _maxDimension = 1600;

  /// Opens the camera, compresses the photo, uploads it, and returns the
  /// public `photo_url` to attach via the existing photo endpoints. Returns
  /// null if the user cancels the picker.
  ///
  /// Superseded by [captureUploadAndAttach] for the task/issue/progress-report
  /// photo flows, which also performs the attach POST (and queues for retry
  /// on a network failure) as part of the same call — kept here as a lower-level
  /// primitive in case a caller ever needs the upload without an immediate attach.
  Future<String?> captureAndUpload({
    required UploadEntityType entityType,
    required ImageSource source,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: _maxDimension.toDouble(),
      maxHeight: _maxDimension.toDouble(),
      imageQuality: _jpegQuality,
    );
    if (picked == null) return null;

    final compressedBytes = await _compress(picked.path);
    final presigned = await _presign(entityType, contentType: 'image/jpeg');
    await _putBytes(presigned.uploadUrl, compressedBytes);
    return presigned.photoUrl;
  }

  /// Maps a queued photo's `target_kind` (`'task'`, `'issue'`, or
  /// `'progress_report'`) to the REST path that attaches a photo to that
  /// entity. Shared by [captureUploadAndAttach] callers (who already know
  /// their own `attachPath`) and [replayQueuedUpload] (which only has
  /// `target_kind`/`target_id` available from the queue row).
  static String attachPathFor({
    required String targetKind,
    required String targetId,
  }) {
    switch (targetKind) {
      case 'task':
        return '/tasks/$targetId/photos';
      case 'issue':
        return '/issues/$targetId/photos';
      case 'progress_report':
        return '/progress-reports/$targetId/photos';
      default:
        throw ArgumentError.value(
          targetKind,
          'targetKind',
          'Unknown photo target kind',
        );
    }
  }

  /// Captures/picks a photo, uploads it to MinIO via a presigned URL, then
  /// POSTs `{photo_url, caption}` to [attachPath] to attach it to the entity
  /// identified by [targetKind]/[targetId] — presign, PUT, and attach are
  /// treated as one atomic unit: replaying only the PUT after a presigned URL
  /// has expired would fail even though the source file is still on disk, so
  /// a retry always redoes all three steps together.
  ///
  /// - Returns `null` if the user cancels the picker.
  /// - On success, returns `fromJson` applied to the attach endpoint's
  ///   response body.
  /// - On a *network* failure (no response reached the server) at any step,
  ///   enqueues the originally-picked file via
  ///   `OfflineQueueRepository.enqueuePhotoUpload` for `PhotoUploadRetryService`
  ///   to replay later, and throws [PhotoUploadQueuedException].
  /// - Any other [ApiException] (validation, permission-denied, etc.)
  ///   propagates unchanged — those are never retried automatically.
  Future<T?> captureUploadAndAttach<T>({
    required UploadEntityType entityType,
    required ImageSource source,
    required String attachPath,
    required String targetKind,
    required String targetId,
    required T Function(Map<String, dynamic> json) fromJson,
    String? caption,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: _maxDimension.toDouble(),
      maxHeight: _maxDimension.toDouble(),
      imageQuality: _jpegQuality,
    );
    if (picked == null) return null;

    try {
      final json = await _uploadAndAttach(
        entityType: entityType,
        localFilePath: picked.path,
        attachPath: attachPath,
        caption: caption,
      );
      return fromJson(json);
    } on ApiException catch (e) {
      if (e.errorCode != 'network_error') rethrow;
      await _queueRepository.enqueuePhotoUpload(
        entityType: entityType.value,
        localFilePath: picked.path,
        caption: caption,
        targetKind: targetKind,
        targetId: targetId,
      );
      throw const PhotoUploadQueuedException();
    }
  }

  /// Replays a single queued photo upload (presign + PUT + attach) from the
  /// file path and target recorded when it was queued. Used only by
  /// `PhotoUploadRetryService` — throws on failure so the caller can decide
  /// whether to mark the row failed vs. leave it pending for the next drain.
  Future<void> replayQueuedUpload({
    required UploadEntityType entityType,
    required String localFilePath,
    required String targetKind,
    required String targetId,
    String? caption,
  }) {
    return _uploadAndAttach(
      entityType: entityType,
      localFilePath: localFilePath,
      attachPath: attachPathFor(targetKind: targetKind, targetId: targetId),
      caption: caption,
    );
  }

  Future<Map<String, dynamic>> _uploadAndAttach({
    required UploadEntityType entityType,
    required String localFilePath,
    required String attachPath,
    String? caption,
  }) async {
    final compressedBytes = await _compress(localFilePath);
    final presigned = await _presign(entityType, contentType: 'image/jpeg');
    await _putBytes(presigned.uploadUrl, compressedBytes);
    final envelope = await _apiClient.post<Map<String, dynamic>>(
      attachPath,
      body: {
        'photo_url': presigned.photoUrl,
        if (caption != null) 'caption': caption,
      },
      fromData: (json) => json as Map<String, dynamic>,
    );
    return envelope.data ?? const <String, dynamic>{};
  }

  Future<void> _putBytes(String uploadUrl, List<int> bytes) async {
    try {
      await _rawDio.put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: 'image/jpeg',
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw ApiException.network(
        'Photo upload failed: ${e.message ?? 'unknown transport error'}',
      );
    }
  }

  Future<Uint8ListWrapper> _compressRaw(String path) async {
    final result = await FlutterImageCompress.compressWithFile(
      path,
      quality: _jpegQuality,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      format: CompressFormat.jpeg,
    );
    if (result == null) {
      return Uint8ListWrapper(await File(path).readAsBytes());
    }
    return Uint8ListWrapper(result);
  }

  Future<List<int>> _compress(String path) async {
    final wrapper = await _compressRaw(path);
    return wrapper.bytes;
  }

  Future<_PresignResult> _presign(
    UploadEntityType entityType, {
    required String contentType,
  }) async {
    final envelope = await _apiClient.post<_PresignResult>(
      '/uploads/presign',
      body: {'entity_type': entityType.value, 'content_type': contentType},
      fromData: (json) => _PresignResult.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}

/// Tiny wrapper so callers don't need a direct `dart:typed_data` import just
/// to pass bytes around.
class Uint8ListWrapper {
  const Uint8ListWrapper(this.bytes);
  final List<int> bytes;
}
