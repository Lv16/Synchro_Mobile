import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/pending_sync_item.dart';
import '../domain/repositories/offline_rdo_repository.dart';
import 'synced_item_cleanup.dart';

class SharedPrefsOfflineRdoRepository implements OfflineRdoRepository {
  static const String _storageKey = 'rdo.mobile.offline_queue.v1';

  @override
  Future<List<PendingSyncItem>> listQueue() async {
    final items = await _readAll();
    items.sort(_sortByBusinessDate);
    return items;
  }

  @override
  Future<List<PendingSyncItem>> listPendingForSync() async {
    final items = await _readAll();
    final filtered = items
        .where(
          (item) =>
              item.state == SyncState.queued ||
              item.state == SyncState.error ||
              item.state == SyncState.conflict,
        )
        .toList(growable: false);
    filtered.sort(_sortByBusinessDate);
    return filtered;
  }

  @override
  Future<void> upsert(PendingSyncItem item) async {
    final items = await _readAll();
    final now = DateTime.now();

    var replaced = false;
    for (var i = 0; i < items.length; i++) {
      if (items[i].clientUuid != item.clientUuid) {
        continue;
      }
      final existing = items[i];
      items[i] = item.copyWith(
        localId: existing.localId,
        createdAt: existing.createdAt ?? item.createdAt ?? now,
        updatedAt: now,
      );
      replaced = true;
      break;
    }

    if (!replaced) {
      items.add(
        item.copyWith(createdAt: item.createdAt ?? now, updatedAt: now),
      );
    }

    await _writeAll(items);
  }

  @override
  Future<void> clearSyncedItems() async {
    final items = await _readAll();
    final filtered = pruneSyncedItemsKeepingDependencies(items);
    await _writeAll(filtered);
  }

  @override
  Future<void> seedDemoData() async {
    final items = await _readAll();
    if (items.isNotEmpty) {
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

    await _writeAll(seed);
  }

  Future<List<PendingSyncItem>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <PendingSyncItem>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <PendingSyncItem>[];
      }

      final out = <PendingSyncItem>[];
      for (final row in decoded) {
        if (row is! Map) {
          continue;
        }
        out.add(PendingSyncItem.fromDbMap(Map<String, dynamic>.from(row)));
      }
      return out;
    } catch (_) {
      return <PendingSyncItem>[];
    }
  }

  Future<void> _writeAll(List<PendingSyncItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = items.map((item) => item.toDbMap()).toList(growable: false);
    await prefs.setString(_storageKey, jsonEncode(rows));
  }

  int _sortByBusinessDate(PendingSyncItem a, PendingSyncItem b) {
    final byDate = a.businessDate.compareTo(b.businessDate);
    if (byDate != 0) {
      return byDate;
    }
    return a.rdoSequence.compareTo(b.rdoSequence);
  }
}
