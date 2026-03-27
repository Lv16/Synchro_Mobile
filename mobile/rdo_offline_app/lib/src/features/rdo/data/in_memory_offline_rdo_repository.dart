import 'package:uuid/uuid.dart';

import '../domain/entities/pending_sync_item.dart';
import '../domain/repositories/offline_rdo_repository.dart';

class InMemoryOfflineRdoRepository implements OfflineRdoRepository {
  final Map<String, PendingSyncItem> _items = <String, PendingSyncItem>{};

  @override
  Future<List<PendingSyncItem>> listQueue() async {
    final list = _items.values.toList()..sort(_sortByBusinessDate);
    return list;
  }

  @override
  Future<List<PendingSyncItem>> listPendingForSync() async {
    final list =
        _items.values
            .where(
              (item) =>
                  item.state == SyncState.queued ||
                  item.state == SyncState.error ||
                  item.state == SyncState.conflict,
            )
            .toList()
          ..sort(_sortByBusinessDate);
    return list;
  }

  @override
  Future<void> upsert(PendingSyncItem item) async {
    _items[item.clientUuid] = item.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> clearSyncedItems() async {
    // Keep synced items in memory so offline export logic matches persisted repos.
    return;
  }

  @override
  Future<void> seedDemoData() async {
    if (_items.isNotEmpty) {
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
        state: SyncState.queued,
        payload: <String, dynamic>{
          'rdo_id': '1',
          'observacoes': 'RDO 1 preenchido offline',
          '__entity_alias': 'rdo_os6044_seq1',
        },
      ),
      PendingSyncItem(
        clientUuid: uuid.v4(),
        operation: 'rdo.tank.add',
        osNumber: '6044',
        rdoSequence: 1,
        businessDate: now.subtract(const Duration(days: 1)),
        state: SyncState.queued,
        payload: <String, dynamic>{
          'rdo_id': '@local:rdo_os6044_seq1',
          'tanque_codigo': '7P',
          'tanque_nome': '7P',
          '__entity_alias': 'tank_os6044_seq1_7p',
          '__depends_on': <String>['rdo_os6044_seq1'],
        },
      ),
      PendingSyncItem(
        clientUuid: uuid.v4(),
        operation: 'rdo.update',
        osNumber: '7120',
        rdoSequence: 3,
        businessDate: now,
        state: SyncState.queued,
        payload: <String, dynamic>{
          'rdo_id': '2',
          'observacoes': 'RDO 3 offline aguardando rede',
        },
      ),
    ];

    for (final item in seed) {
      _items[item.clientUuid] = item;
    }
  }

  int _sortByBusinessDate(PendingSyncItem a, PendingSyncItem b) {
    final byDate = a.businessDate.compareTo(b.businessDate);
    if (byDate != 0) {
      return byDate;
    }
    return a.rdoSequence.compareTo(b.rdoSequence);
  }
}
