import 'package:flutter_test/flutter_test.dart';

import 'package:rdo_offline_app/src/features/rdo/application/offline_sync_controller.dart';
import 'package:rdo_offline_app/src/features/rdo/application/rdo_sync_gateway.dart';
import 'package:rdo_offline_app/src/features/rdo/data/in_memory_offline_rdo_repository.dart';
import 'package:rdo_offline_app/src/features/rdo/domain/entities/pending_sync_item.dart';

class _RecordingBatchGateway implements RdoSyncGateway, BatchRdoSyncGateway {
  List<PendingSyncItem> lastBatchItems = const <PendingSyncItem>[];
  bool throwOnBatch = false;

  @override
  Future<SyncExecutionResult> syncItem(PendingSyncItem item) async {
    return const SyncExecutionResult(success: true);
  }

  @override
  Future<List<BatchSyncExecutionResult>> syncItems(
    List<PendingSyncItem> items,
  ) async {
    if (throwOnBatch) {
      throw Exception('forced-batch-error');
    }
    lastBatchItems = List<PendingSyncItem>.from(items);
    return items
        .map(
          (item) => BatchSyncExecutionResult(
            clientUuid: item.clientUuid,
            success: true,
          ),
        )
        .toList(growable: false);
  }
}

void main() {
  test(
    'batch inclui dependencias ja sincronizadas para resolver aliases locais',
    () async {
      final repository = InMemoryOfflineRdoRepository();
      final now = DateTime(2026, 2, 22);

      const createUuid = 'create-uuid-01';
      const updateUuid = 'update-uuid-01';

      await repository.upsert(
        PendingSyncItem(
          clientUuid: createUuid,
          operation: 'rdo.create',
          osNumber: '5261',
          rdoSequence: 1,
          businessDate: now,
          payload: const <String, dynamic>{
            '__entity_alias': 'rdo_alias_5261_1',
            'ordem_servico_id': '105',
          },
          state: SyncState.synced,
        ),
      );

      await repository.upsert(
        PendingSyncItem(
          clientUuid: updateUuid,
          operation: 'rdo.update',
          osNumber: '5261',
          rdoSequence: 1,
          businessDate: now,
          payload: const <String, dynamic>{
            'rdo_id': '@local:rdo_alias_5261_1',
            '__depends_on': <String>['rdo_alias_5261_1'],
            'observacoes': 'teste',
          },
          state: SyncState.error,
        ),
      );

      final gateway = _RecordingBatchGateway();
      final controller = OfflineSyncController(repository, gateway);

      await controller.syncQueuedItems();

      final executedUuids = gateway.lastBatchItems
          .map((item) => item.clientUuid)
          .toSet();
      expect(executedUuids.contains(createUuid), isTrue);
      expect(executedUuids.contains(updateUuid), isTrue);

      final queue = await repository.listQueue();
      final updated = queue.firstWhere((item) => item.clientUuid == updateUuid);
      expect(updated.state, SyncState.synced);
      expect(controller.message, contains('sincronizado'));
    },
  );

  test(
    'falha inesperada converte itens syncing para erro com retry incrementado',
    () async {
      final repository = InMemoryOfflineRdoRepository();
      final now = DateTime(2026, 2, 22);

      await repository.upsert(
        PendingSyncItem(
          clientUuid: 'update-uuid-02',
          operation: 'rdo.update',
          osNumber: '5261',
          rdoSequence: 2,
          businessDate: now,
          payload: const <String, dynamic>{
            'rdo_id': '123',
            'observacoes': 'teste',
          },
          state: SyncState.queued,
        ),
      );

      final gateway = _RecordingBatchGateway()..throwOnBatch = true;
      final controller = OfflineSyncController(repository, gateway);

      await controller.syncQueuedItems();

      final queue = await repository.listQueue();
      final item = queue.first;
      expect(item.state, SyncState.error);
      expect(item.retryCount, 1);
      expect(item.lastError, contains('Falha inesperada ao sincronizar'));
      expect(controller.message, contains('Falha ao sincronizar fila'));
    },
  );
}
