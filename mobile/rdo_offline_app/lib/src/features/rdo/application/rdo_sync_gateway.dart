import '../domain/entities/pending_sync_item.dart';

class SyncExecutionResult {
  const SyncExecutionResult({
    required this.success,
    this.conflict = false,
    this.errorMessage,
  });

  final bool success;
  final bool conflict;
  final String? errorMessage;
}

class BatchSyncExecutionResult {
  const BatchSyncExecutionResult({
    required this.clientUuid,
    required this.success,
    this.conflict = false,
    this.blocked = false,
    this.errorMessage,
  });

  final String clientUuid;
  final bool success;
  final bool conflict;
  final bool blocked;
  final String? errorMessage;
}

abstract class RdoSyncGateway {
  Future<SyncExecutionResult> syncItem(PendingSyncItem item);
}

abstract class BatchRdoSyncGateway {
  Future<List<BatchSyncExecutionResult>> syncItems(List<PendingSyncItem> items);
}
