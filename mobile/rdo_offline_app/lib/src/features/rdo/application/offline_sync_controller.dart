import 'package:flutter/foundation.dart';

import '../domain/entities/pending_sync_item.dart';
import '../domain/repositories/offline_rdo_repository.dart';
import 'rdo_sync_gateway.dart';

class OfflineSyncController extends ChangeNotifier {
  OfflineSyncController(this._repository, this._gateway);

  static const String _metaEntityAliasKey = '__entity_alias';
  static const String _metaDependsOnKey = '__depends_on';
  static const String _localRefPrefix = '@local:';
  static const String _serverRefPrefix = '@ref:';

  final OfflineRdoRepository _repository;
  final RdoSyncGateway _gateway;

  List<PendingSyncItem> _items = const <PendingSyncItem>[];
  bool _busy = false;
  String? _message;
  int _lastRoundSuccessCount = 0;
  int _lastRoundFailureCount = 0;
  int _lastRoundSuccessRdoCount = 0;

  List<PendingSyncItem> get items => _items;
  bool get busy => _busy;
  String? get message => _message;
  int get lastRoundSuccessCount => _lastRoundSuccessCount;
  int get lastRoundFailureCount => _lastRoundFailureCount;
  int get lastRoundSuccessRdoCount => _lastRoundSuccessRdoCount;

  int get queuedCount => _items
      .where(
        (item) =>
            item.state == SyncState.queued ||
            item.state == SyncState.syncing ||
            item.state == SyncState.error ||
            item.state == SyncState.conflict,
      )
      .length;

  int get syncedCount =>
      _items.where((item) => item.state == SyncState.synced).length;

  int get errorCount => _items
      .where(
        (item) =>
            item.state == SyncState.error || item.state == SyncState.conflict,
      )
      .length;

  Future<void> loadQueue() async {
    _items = await _repository.listQueue();
    notifyListeners();
  }

  Future<void> seedDemoQueue() async {
    await _repository.seedDemoData();
    _message = 'Fila demo persistida localmente.';
    await loadQueue();
  }

  Future<void> syncQueuedItems() async {
    if (_busy) {
      return;
    }
    _busy = true;
    _message = null;
    _lastRoundSuccessCount = 0;
    _lastRoundFailureCount = 0;
    _lastRoundSuccessRdoCount = 0;
    notifyListeners();

    try {
      final pendingQueue = await _repository.listPendingForSync();
      if (pendingQueue.isEmpty) {
        _message = 'Nenhum item pendente para sincronizar.';
        return;
      }

      for (final item in pendingQueue) {
        await _repository.upsert(
          item.copyWith(state: SyncState.syncing, clearLastError: true),
        );
      }
      await loadQueue();

      List<PendingSyncItem> executionQueue = pendingQueue;
      if (_gateway is BatchRdoSyncGateway) {
        final fullQueue = await _repository.listQueue();
        executionQueue = _buildBatchExecutionQueue(pendingQueue, fullQueue);
      }

      if (_gateway is BatchRdoSyncGateway) {
        await _syncUsingBatch(
          executionQueue,
          pendingQueue,
          _gateway as BatchRdoSyncGateway,
        );
      } else {
        await _syncSequential(pendingQueue);
      }

      final summary = await _summarizeRound(pendingQueue);
      _lastRoundSuccessCount = summary.success;
      _lastRoundFailureCount = summary.failed;
      _lastRoundSuccessRdoCount = summary.successfulRdoCount;
      if (summary.failed == 0) {
        final label = summary.success == 1 ? 'item' : 'itens';
        final verb = summary.success == 1 ? 'sincronizado' : 'sincronizados';
        _message = '${summary.success} $label $verb com sucesso.';
      } else if (summary.success > 0) {
        _message =
            'Sincronização parcial: ${summary.success} enviados, ${summary.failed} com falha.';
      } else {
        _message =
            'Falha ao sincronizar: ${summary.failed} item(ns) com erro. Revise a fila.';
      }

      if (summary.success > 0) {
        await _repository.clearSyncedItems();
      }
    } catch (err) {
      await _markSyncingItemsAsError('Falha inesperada ao sincronizar: $err');
      _message =
          'Falha ao sincronizar fila. Verifique conexão/sessão e tente novamente.';
    } finally {
      _busy = false;
      await loadQueue();
    }
  }

  Future<void> _syncSequential(List<PendingSyncItem> queue) async {
    for (final item in queue) {
      final result = await _gateway.syncItem(item);
      await _applySingleResult(item, result);
      await loadQueue();
    }
  }

  Future<void> _syncUsingBatch(
    List<PendingSyncItem> executionQueue,
    List<PendingSyncItem> pendingQueue,
    BatchRdoSyncGateway batchGateway,
  ) async {
    final results = await batchGateway.syncItems(executionQueue);
    final resultByUuid = <String, BatchSyncExecutionResult>{
      for (final result in results) result.clientUuid: result,
    };

    for (final item in pendingQueue) {
      final batchResult = resultByUuid[item.clientUuid];
      if (batchResult == null) {
        await _repository.upsert(
          item.copyWith(
            state: SyncState.error,
            retryCount: item.retryCount + 1,
            lastError: 'Item não retornado pelo batch de sincronização.',
          ),
        );
        continue;
      }

      if (batchResult.success) {
        await _repository.upsert(
          item.copyWith(state: SyncState.synced, clearLastError: true),
        );
        continue;
      }

      if (batchResult.conflict || batchResult.blocked) {
        await _repository.upsert(
          item.copyWith(
            state: SyncState.conflict,
            retryCount: item.retryCount + 1,
            lastError: batchResult.errorMessage,
          ),
        );
        continue;
      }

      await _repository.upsert(
        item.copyWith(
          state: SyncState.error,
          retryCount: item.retryCount + 1,
          lastError: batchResult.errorMessage,
        ),
      );
    }

    await loadQueue();
  }

  Future<void> _applySingleResult(
    PendingSyncItem item,
    SyncExecutionResult result,
  ) async {
    if (result.success) {
      await _repository.upsert(
        item.copyWith(state: SyncState.synced, clearLastError: true),
      );
      return;
    }

    if (result.conflict) {
      await _repository.upsert(
        item.copyWith(
          state: SyncState.conflict,
          retryCount: item.retryCount + 1,
          lastError: result.errorMessage,
        ),
      );
      return;
    }

    await _repository.upsert(
      item.copyWith(
        state: SyncState.error,
        retryCount: item.retryCount + 1,
        lastError: result.errorMessage,
      ),
    );
  }

  List<PendingSyncItem> _buildBatchExecutionQueue(
    List<PendingSyncItem> pendingQueue,
    List<PendingSyncItem> fullQueue,
  ) {
    final byUuid = <String, PendingSyncItem>{
      for (final item in fullQueue) item.clientUuid: item,
    };
    final byAlias = <String, PendingSyncItem>{};
    for (final item in fullQueue) {
      final alias = _normalizeAlias(item.payload[_metaEntityAliasKey]);
      if (alias != null && !byAlias.containsKey(alias)) {
        byAlias[alias] = item;
      }
      if (!byAlias.containsKey(item.clientUuid)) {
        byAlias[item.clientUuid] = item;
      }
    }

    final selectedByUuid = <String, PendingSyncItem>{
      for (final item in pendingQueue) item.clientUuid: item,
    };
    final dependenciesToVisit = <String>[];
    for (final item in pendingQueue) {
      dependenciesToVisit.addAll(_collectDependencyKeys(item.payload));
    }

    var cursor = 0;
    while (cursor < dependenciesToVisit.length) {
      final depKey = dependenciesToVisit[cursor].trim();
      cursor += 1;
      if (depKey.isEmpty) {
        continue;
      }

      final depItem = byUuid[depKey] ?? byAlias[depKey];
      if (depItem == null) {
        continue;
      }
      if (depItem.state == SyncState.draft) {
        continue;
      }
      if (selectedByUuid.containsKey(depItem.clientUuid)) {
        continue;
      }

      selectedByUuid[depItem.clientUuid] = depItem;
      dependenciesToVisit.addAll(_collectDependencyKeys(depItem.payload));
    }

    final selectedUuids = selectedByUuid.keys.toSet();
    return fullQueue
        .where((item) => selectedUuids.contains(item.clientUuid))
        .toList(growable: false);
  }

  List<String> _collectDependencyKeys(Map<String, dynamic> payload) {
    final out = <String>{};

    void addKey(dynamic raw) {
      final key = (raw ?? '').toString().trim();
      if (key.isNotEmpty) {
        out.add(key);
      }
    }

    final explicit = payload[_metaDependsOnKey];
    if (explicit is List) {
      for (final entry in explicit) {
        addKey(entry);
      }
    } else if (explicit is Map) {
      for (final entry in explicit.values) {
        addKey(entry);
      }
    } else if (explicit != null) {
      addKey(explicit);
    }

    void walk(dynamic value) {
      if (value is String) {
        final raw = value.trim();
        if (raw.startsWith(_localRefPrefix)) {
          addKey(raw.substring(_localRefPrefix.length));
        } else if (raw.startsWith(_serverRefPrefix)) {
          addKey(raw.substring(_serverRefPrefix.length));
        }
        return;
      }

      if (value is List) {
        for (final entry in value) {
          walk(entry);
        }
        return;
      }

      if (value is Map) {
        if (value.length == 1 && value.containsKey(r'$ref')) {
          addKey(value[r'$ref']);
        }
        for (final entry in value.values) {
          walk(entry);
        }
      }
    }

    walk(payload);
    return out.toList(growable: false);
  }

  String? _normalizeAlias(dynamic value) {
    final alias = (value ?? '').toString().trim();
    if (alias.isEmpty) {
      return null;
    }
    return alias;
  }

  Future<_SyncRoundSummary> _summarizeRound(
    List<PendingSyncItem> attemptedItems,
  ) async {
    final queue = await _repository.listQueue();
    final stateByUuid = <String, SyncState>{
      for (final item in queue) item.clientUuid: item.state,
    };

    var success = 0;
    var failed = 0;
    final successfulRdos = <String>{};
    for (final attempted in attemptedItems) {
      final state = stateByUuid[attempted.clientUuid];
      if (state == SyncState.synced) {
        success += 1;
        successfulRdos.add(
          '${attempted.osNumber.trim()}#${attempted.rdoSequence}',
        );
      } else {
        failed += 1;
      }
    }
    return _SyncRoundSummary(
      success: success,
      failed: failed,
      successfulRdoCount: successfulRdos.length,
    );
  }

  Future<void> _markSyncingItemsAsError(String reason) async {
    final queue = await _repository.listQueue();
    final normalizedReason = reason.trim().isEmpty
        ? 'Falha inesperada na sincronização.'
        : reason.trim();
    for (final item in queue) {
      if (item.state != SyncState.syncing) {
        continue;
      }
      await _repository.upsert(
        item.copyWith(
          state: SyncState.error,
          retryCount: item.retryCount + 1,
          lastError: normalizedReason,
        ),
      );
    }
  }
}

class _SyncRoundSummary {
  const _SyncRoundSummary({
    required this.success,
    required this.failed,
    required this.successfulRdoCount,
  });

  final int success;
  final int failed;
  final int successfulRdoCount;
}
