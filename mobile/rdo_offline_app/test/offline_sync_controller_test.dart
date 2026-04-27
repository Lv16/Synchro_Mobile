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

class _PartialSuccessBatchGateway
    implements RdoSyncGateway, BatchRdoSyncGateway {
  int round = 0;
  List<PendingSyncItem> lastBatchItems = const <PendingSyncItem>[];

  @override
  Future<SyncExecutionResult> syncItem(PendingSyncItem item) async {
    return const SyncExecutionResult(success: true);
  }

  @override
  Future<List<BatchSyncExecutionResult>> syncItems(
    List<PendingSyncItem> items,
  ) async {
    round += 1;
    lastBatchItems = List<PendingSyncItem>.from(items);

    if (round == 1) {
      return items
          .map((item) {
            if (item.operation.toLowerCase() == 'rdo.create') {
              return BatchSyncExecutionResult(
                clientUuid: item.clientUuid,
                success: true,
              );
            }
            return BatchSyncExecutionResult(
              clientUuid: item.clientUuid,
              success: false,
              conflict: true,
              blocked: true,
              errorMessage: 'dependências ausentes: rdo_alias_6319_5',
            );
          })
          .toList(growable: false);
    }

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
      expect(queue, isEmpty);
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

  test(
    'mantem dependencia sincronizada na fila quando item dependente falha e reaproveita no retry',
    () async {
      final repository = InMemoryOfflineRdoRepository();
      final now = DateTime(2026, 4, 8);

      const createUuid = 'create-uuid-6319-5';
      const updateUuid = 'update-uuid-6319-5';

      await repository.upsert(
        PendingSyncItem(
          clientUuid: createUuid,
          operation: 'rdo.create',
          osNumber: '6319',
          rdoSequence: 5,
          businessDate: now,
          payload: const <String, dynamic>{
            '__entity_alias': 'rdo_alias_6319_5',
            'ordem_servico_id': '244',
            'rdo_contagem': '5',
          },
          state: SyncState.queued,
        ),
      );

      await repository.upsert(
        PendingSyncItem(
          clientUuid: updateUuid,
          operation: 'rdo.update',
          osNumber: '6319',
          rdoSequence: 5,
          businessDate: now,
          payload: const <String, dynamic>{
            'rdo_id': '@local:rdo_alias_6319_5',
            '__depends_on': <String>['rdo_alias_6319_5'],
            'observacoes': 'RDO offline',
          },
          state: SyncState.queued,
        ),
      );

      final gateway = _PartialSuccessBatchGateway();
      final controller = OfflineSyncController(repository, gateway);

      await controller.syncQueuedItems();

      var queue = await repository.listQueue();
      expect(queue.map((item) => item.clientUuid), contains(createUuid));
      expect(queue.map((item) => item.clientUuid), contains(updateUuid));

      final retainedCreate = queue.firstWhere(
        (item) => item.clientUuid == createUuid,
      );
      final conflictedUpdate = queue.firstWhere(
        (item) => item.clientUuid == updateUuid,
      );
      expect(retainedCreate.state, SyncState.synced);
      expect(conflictedUpdate.state, SyncState.conflict);

      await controller.syncQueuedItems();

      final executedUuids = gateway.lastBatchItems
          .map((item) => item.clientUuid)
          .toSet();
      expect(executedUuids.contains(createUuid), isTrue);
      expect(executedUuids.contains(updateUuid), isTrue);

      queue = await repository.listQueue();
      expect(queue, isEmpty);
      expect(controller.queuedCount, 0);
      expect(controller.errorCount, 0);
    },
  );

  test(
    'reprocessa item que ficou preso como syncing em execucao anterior',
    () async {
      final repository = InMemoryOfflineRdoRepository();
      final now = DateTime(2026, 4, 22);

      await repository.upsert(
        PendingSyncItem(
          clientUuid: 'stale-syncing-create-6326-18',
          operation: 'rdo.create',
          osNumber: '6326',
          rdoSequence: 18,
          businessDate: now,
          payload: const <String, dynamic>{
            '__entity_alias': 'rdo_os275_seq18_123',
            'ordem_servico_id': '275',
            'rdo_contagem': '18',
          },
          state: SyncState.syncing,
        ),
      );

      final gateway = _RecordingBatchGateway();
      final controller = OfflineSyncController(repository, gateway);

      await controller.loadQueue();
      expect(controller.queuedCount, 1);

      await controller.syncQueuedItems();

      expect(gateway.lastBatchItems, hasLength(1));
      expect(
        gateway.lastBatchItems.first.clientUuid,
        'stale-syncing-create-6326-18',
      );

      final queue = await repository.listQueue();
      expect(queue, isEmpty);
      expect(controller.queuedCount, 0);
      expect(controller.errorCount, 0);
    },
  );
}
