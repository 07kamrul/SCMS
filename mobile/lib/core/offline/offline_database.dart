import 'dart:async';

import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

/// Table names for the offline retry queues. Shared with
/// [OfflineQueueRepository] so callers never hand-type a table string.
const String queuedLocationsTable = 'queued_locations';
const String queuedPhotoUploadsTable = 'queued_photo_uploads';
const String queuedSubmissionsTable = 'queued_submissions';

const String _databaseFileName = 'scfms_offline_queue.db';
const int _databaseVersion = 1;

/// Cached per-isolate. `sqflite` opens a real OS file handle keyed by path,
/// so re-opening from the same isolate is cheap but unnecessary — caching
/// the [Database] here avoids repeating the `onCreate` round trip on every
/// call. Each isolate that imports this library gets its own cache, which is
/// exactly what's needed: the main isolate and any background isolate (e.g.
/// the location foreground-service isolate, once it has called
/// `BackgroundIsolateBinaryMessenger.ensureInitialized` with the handed-off
/// `RootIsolateToken` — that handoff is done by the caller, not here) each
/// open their own connection to the same on-disk database file.
Database? _cachedDatabase;
Future<Database>? _openFuture;

/// Opens (or returns the cached handle to) the single sqflite database used
/// for offline retry queues: location pings, photo uploads, and task/report
/// submissions that must survive a connectivity loss.
///
/// Safe to call from the main isolate or from a background isolate — it
/// assumes nothing about `getIt` or any other main-isolate-only singleton.
/// If called from a background isolate, the caller is responsible for
/// having already run `BackgroundIsolateBinaryMessenger.ensureInitialized`
/// with a `RootIsolateToken` before the first call, per the platform
/// channel requirement for plugins used outside the main isolate.
Future<Database> getOfflineDatabase() {
  final existing = _cachedDatabase;
  if (existing != null) return Future.value(existing);

  // Guards against two concurrent first-callers in the same isolate both
  // triggering `openDatabase`.
  return _openFuture ??= _openDatabase().then((db) {
    _cachedDatabase = db;
    _openFuture = null;
    return db;
  });
}

Future<Database> _openDatabase() async {
  final directory = await getDatabasesPath();
  final path = join(directory, _databaseFileName);
  return openDatabase(
    path,
    version: _databaseVersion,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE $queuedLocationsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending'
        )
      ''');
      await db.execute('''
        CREATE TABLE $queuedPhotoUploadsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          local_file_path TEXT NOT NULL,
          caption TEXT,
          target_kind TEXT NOT NULL,
          target_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending'
        )
      ''');
      await db.execute('''
        CREATE TABLE $queuedSubmissionsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kind TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending'
        )
      ''');
    },
  );
}
