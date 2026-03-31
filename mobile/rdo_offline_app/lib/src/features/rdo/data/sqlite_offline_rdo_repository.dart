import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/pending_sync_item.dart';
import '../domain/repositories/offline_rdo_repository.dart';

class SqliteOfflineRdoRepository implements OfflineRdoRepository {
  static const String _tableName = 'offline_sync_queue';

  Database? _database;

  Future<Database> _db() async {
    if (_database != null) {
      return _database!;
    }

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'rdo_offline.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_uuid TEXT NOT NULL UNIQUE,
            operation TEXT NOT NULL,
            os_number TEXT NOT NULL,
            rdo_sequence INTEGER NOT NULL,
            business_date TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            state TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_offline_sync_state ON $_tableName(state)',
        );
        await db.execute(
          'CREATE INDEX idx_offline_sync_business_date ON $_tableName(business_date)',
        );
      },
    );

    return _database!;
  }

  @override
  Future<List<PendingSyncItem>> listQueue() async {
    final db = await _db();
    final rows = await db.query(
      _tableName,
      orderBy: 'business_date ASC, rdo_sequence ASC, id ASC',
    );
    return rows.map(PendingSyncItem.fromDbMap).toList();
  }

  @override
  Future<List<PendingSyncItem>> listPendingForSync() async {
    final db = await _db();
    final rows = await db.query(
      _tableName,
      where: 'state IN (?, ?, ?)',
      whereArgs: <Object?>[
        SyncState.queued.name,
        SyncState.error.name,
        SyncState.conflict.name,
      ],
      orderBy: 'business_date ASC, rdo_sequence ASC, id ASC',
    );
    return rows.map(PendingSyncItem.fromDbMap).toList();
  }

  @override
  Future<void> upsert(PendingSyncItem item) async {
    final db = await _db();
    final now = DateTime.now();

    final exists = await db.query(
      _tableName,
      columns: <String>['id', 'created_at'],
      where: 'client_uuid = ?',
      whereArgs: <Object?>[item.clientUuid],
      limit: 1,
    );

    if (exists.isNotEmpty) {
      final row = exists.first;
      final merged = item.copyWith(
        localId: row['id'] as int?,
        createdAt:
            DateTime.tryParse('${row['created_at'] ?? ''}') ??
            item.createdAt ??
            now,
        updatedAt: now,
      );
      await db.update(
        _tableName,
        merged.toDbMap()..remove('id'),
        where: 'client_uuid = ?',
        whereArgs: <Object?>[item.clientUuid],
      );
      return;
    }

    final insertItem = item.copyWith(createdAt: now, updatedAt: now);
    await db.insert(
      _tableName,
      insertItem.toDbMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearSyncedItems() async {
    final db = await _db();
    await db.delete(
      _tableName,
      where: 'state = ?',
      whereArgs: <Object?>[SyncState.synced.name],
    );
  }

  @override
  Future<void> seedDemoData() async {
    final db = await _db();
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_tableName',
    );
    final total = Sqflite.firstIntValue(countResult) ?? 0;
    if (total > 0) {
      return;
    }

    final now = DateTime.now();
    final uuid = const Uuid();
    final seed = <PendingSyncItem>[
      PendingSyncItem(
        clientUuid: uuid.v4(),
        operation: 'rdo.update',
        osNumber: '6044',
        rdoSequence: 1,
        businessDate: now.subtract(const Duration(days: 2)),
        payload: <String, dynamic>{
          'rdo_id': '1',
          'observacoes': 'RDO 1 preenchido offline no app',
          '__entity_alias': 'rdo_os6044_seq1',
        },
        state: SyncState.queued,
      ),
      PendingSyncItem(
        clientUuid: uuid.v4(),
        operation: 'rdo.tank.add',
        osNumber: '6044',
        rdoSequence: 1,
        businessDate: now.subtract(const Duration(days: 1)),
        payload: <String, dynamic>{
          'rdo_id': '@local:rdo_os6044_seq1',
          'tanque_codigo': '2P',
          'tanque_nome': '2P',
          '__entity_alias': 'tank_os6044_seq1_2p',
          '__depends_on': <String>['rdo_os6044_seq1'],
        },
        state: SyncState.queued,
      ),
      PendingSyncItem(
        clientUuid: uuid.v4(),
        operation: 'rdo.update',
        osNumber: '7120',
        rdoSequence: 3,
        businessDate: now,
        payload: <String, dynamic>{
          'rdo_id': '2',
          'observacoes': 'RDO 3 preenchido durante embarque sem rede',
        },
        state: SyncState.queued,
      ),
    ];

    final batch = db.batch();
    for (final item in seed) {
      batch.insert(
        _tableName,
        item.copyWith(createdAt: now, updatedAt: now).toDbMap()..remove('id'),
      );
    }
    await batch.commit(noResult: true);
  }
}
