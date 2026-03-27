import '../entities/pending_sync_item.dart';

abstract class OfflineRdoRepository {
  Future<List<PendingSyncItem>> listQueue();

  Future<List<PendingSyncItem>> listPendingForSync();

  Future<void> upsert(PendingSyncItem item);

  Future<void> clearSyncedItems();

  Future<void> seedDemoData();
}
