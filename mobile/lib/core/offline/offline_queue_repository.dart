import 'package:sqflite/sqflite.dart';

import 'offline_database.dart';

/// Thin CRUD layer over the offline retry queues (`queued_locations`,
/// `queued_photo_uploads`, `queued_submissions`). Deliberately dumb: no
/// retry scheduling, backoff, or give-up-after-N-failures logic lives here —
/// that belongs to whichever flow (location tracking, photo upload,
/// task/report submission) actually replays these rows once connectivity
/// returns.
class OfflineQueueRepository {
  OfflineQueueRepository({Future<Database> Function()? openDatabase})
    : _openDatabase = openDatabase ?? getOfflineDatabase;

  final Future<Database> Function() _openDatabase;

  Future<int> enqueueLocation(String jsonPayload) async {
    final db = await _openDatabase();
    return db.insert(queuedLocationsTable, {
      'payload': jsonPayload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<int> enqueuePhotoUpload({
    required String entityType,
    required String localFilePath,
    String? caption,
    required String targetKind,
    required String targetId,
  }) async {
    final db = await _openDatabase();
    return db.insert(queuedPhotoUploadsTable, {
      'entity_type': entityType,
      'local_file_path': localFilePath,
      'caption': caption,
      'target_kind': targetKind,
      'target_id': targetId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<int> enqueueSubmission({
    required String kind,
    required String jsonPayload,
  }) async {
    final db = await _openDatabase();
    return db.insert(queuedSubmissionsTable, {
      'kind': kind,
      'payload': jsonPayload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<List<Map<String, Object?>>> pendingLocations() =>
      _pendingRowsOf(queuedLocationsTable);

  Future<List<Map<String, Object?>>> pendingPhotoUploads() =>
      _pendingRowsOf(queuedPhotoUploadsTable);

  Future<List<Map<String, Object?>>> pendingSubmissions() =>
      _pendingRowsOf(queuedSubmissionsTable);

  Future<List<Map<String, Object?>>> _pendingRowsOf(String table) async {
    final db = await _openDatabase();
    return db.query(
      table,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'id ASC',
    );
  }

  /// A row that has been successfully replayed is deleted outright — it's no
  /// longer needed and this keeps the queue tables from growing without
  /// bound.
  Future<void> markSent(String table, int id) async {
    final db = await _openDatabase();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// Marks a row `failed` rather than deleting it, so a later retry flow can
  /// decide whether to give up on it (e.g. after N attempts) instead of
  /// silently losing it.
  Future<void> markFailed(String table, int id) async {
    final db = await _openDatabase();
    await db.update(
      table,
      {'status': 'failed'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
