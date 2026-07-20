import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/offline/offline_database.dart';
import 'package:mobile/core/offline/offline_queue_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a brand-new, isolated in-memory sqflite database whose schema
/// mirrors `offline_database.dart`'s `onCreate` exactly. `OfflineQueueRepository`
/// accepts an injectable `openDatabase` factory (it defaults to the
/// process-wide `getOfflineDatabase()` singleton), which is the seam these
/// tests use to avoid ever touching that cached global handle — each test
/// gets its own database, so tests never share state or leak files.
///
/// `singleInstance: false` matters here: sqflite/sqflite_common_ffi normally
/// caches one `Database` per path, and every in-memory database shares the
/// literal path `inMemoryDatabasePath`. Without disabling that cache, the
/// second test to open "the same path" would be handed back the first
/// test's (by-then-closed) database instead of a fresh one.
Future<Database> _openTestDatabase() {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
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
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late OfflineQueueRepository repository;

  setUp(() async {
    db = await _openTestDatabase();
    repository = OfflineQueueRepository(openDatabase: () async => db);
  });

  tearDown(() async {
    await db.close();
  });

  group('enqueueLocation', () {
    test('inserts a row with status pending', () async {
      final id = await repository.enqueueLocation('{"lat":1.0,"lng":2.0}');

      final rows = await db.query(queuedLocationsTable);
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['id'], id);
      expect(row['payload'], '{"lat":1.0,"lng":2.0}');
      expect(row['status'], 'pending');
      expect(row['created_at'], isNotNull);
    });
  });

  group('enqueuePhotoUpload', () {
    test('inserts a row with status pending', () async {
      final id = await repository.enqueuePhotoUpload(
        entityType: 'issue_photo',
        localFilePath: '/tmp/photo.jpg',
        caption: 'crack in wall',
        targetKind: 'issue',
        targetId: 'issue-1',
      );

      final rows = await db.query(queuedPhotoUploadsTable);
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['id'], id);
      expect(row['entity_type'], 'issue_photo');
      expect(row['local_file_path'], '/tmp/photo.jpg');
      expect(row['caption'], 'crack in wall');
      expect(row['target_kind'], 'issue');
      expect(row['target_id'], 'issue-1');
      expect(row['status'], 'pending');
      expect(row['created_at'], isNotNull);
    });

    test('allows a null caption', () async {
      await repository.enqueuePhotoUpload(
        entityType: 'issue_photo',
        localFilePath: '/tmp/photo.jpg',
        targetKind: 'issue',
        targetId: 'issue-1',
      );

      final rows = await db.query(queuedPhotoUploadsTable);
      expect(rows.single['caption'], isNull);
    });
  });

  group('enqueueSubmission', () {
    test('inserts a row with status pending', () async {
      final id = await repository.enqueueSubmission(
        kind: 'task_report',
        jsonPayload: '{"taskId":"t-1"}',
      );

      final rows = await db.query(queuedSubmissionsTable);
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['id'], id);
      expect(row['kind'], 'task_report');
      expect(row['payload'], '{"taskId":"t-1"}');
      expect(row['status'], 'pending');
      expect(row['created_at'], isNotNull);
    });
  });

  group('pendingLocations', () {
    test('returns only pending rows, oldest first', () async {
      final firstId = await repository.enqueueLocation('{"seq":1}');
      final secondId = await repository.enqueueLocation('{"seq":2}');
      final thirdId = await repository.enqueueLocation('{"seq":3}');

      // Mark the middle one failed — it must disappear from pending results.
      await repository.markFailed(queuedLocationsTable, secondId);

      final pending = await repository.pendingLocations();

      expect(pending.map((r) => r['id']), [firstId, thirdId]);
      expect(pending.map((r) => r['payload']), ['{"seq":1}', '{"seq":3}']);
    });

    test('returns an empty list when there are no pending rows', () async {
      expect(await repository.pendingLocations(), isEmpty);
    });
  });

  group('pendingPhotoUploads', () {
    test('returns only pending rows, oldest first', () async {
      final firstId = await repository.enqueuePhotoUpload(
        entityType: 'issue_photo',
        localFilePath: '/tmp/1.jpg',
        targetKind: 'issue',
        targetId: 'issue-1',
      );
      final secondId = await repository.enqueuePhotoUpload(
        entityType: 'issue_photo',
        localFilePath: '/tmp/2.jpg',
        targetKind: 'issue',
        targetId: 'issue-2',
      );

      await repository.markFailed(queuedPhotoUploadsTable, firstId);

      final pending = await repository.pendingPhotoUploads();

      expect(pending.map((r) => r['id']), [secondId]);
    });
  });

  group('pendingSubmissions', () {
    test('returns only pending rows, oldest first', () async {
      final firstId = await repository.enqueueSubmission(
        kind: 'task_report',
        jsonPayload: '{"seq":1}',
      );
      final secondId = await repository.enqueueSubmission(
        kind: 'task_report',
        jsonPayload: '{"seq":2}',
      );
      final thirdId = await repository.enqueueSubmission(
        kind: 'task_report',
        jsonPayload: '{"seq":3}',
      );

      final pending = await repository.pendingSubmissions();

      expect(pending.map((r) => r['id']), [firstId, secondId, thirdId]);
    });
  });

  group('markSent', () {
    test('deletes the row outright', () async {
      final id = await repository.enqueueLocation('{"seq":1}');

      await repository.markSent(queuedLocationsTable, id);

      final rows = await db.query(queuedLocationsTable);
      expect(rows, isEmpty);
    });

    test('leaves other rows untouched', () async {
      final keepId = await repository.enqueueLocation('{"seq":1}');
      final sentId = await repository.enqueueLocation('{"seq":2}');

      await repository.markSent(queuedLocationsTable, sentId);

      final pending = await repository.pendingLocations();
      expect(pending.map((r) => r['id']), [keepId]);
    });
  });

  group('markFailed', () {
    test('sets status to failed without deleting the row', () async {
      final id = await repository.enqueueLocation('{"seq":1}');

      await repository.markFailed(queuedLocationsTable, id);

      final rows = await db.query(queuedLocationsTable);
      expect(rows, hasLength(1));
      expect(rows.single['status'], 'failed');
    });

    test('excludes the row from the pending query afterwards', () async {
      final id = await repository.enqueueSubmission(
        kind: 'task_report',
        jsonPayload: '{"seq":1}',
      );

      await repository.markFailed(queuedSubmissionsTable, id);

      expect(await repository.pendingSubmissions(), isEmpty);
    });
  });
}
