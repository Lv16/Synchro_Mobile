import '../application/rdo_sync_gateway.dart';
import '../domain/entities/pending_sync_item.dart';

class DemoRdoSyncGateway implements RdoSyncGateway, BatchRdoSyncGateway {
  @override
  Future<SyncExecutionResult> syncItem(PendingSyncItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (item.osNumber == '7120' && item.retryCount == 0) {
      return const SyncExecutionResult(
        success: false,
        errorMessage: 'Sem conectividade no envio do pacote.',
      );
    }

    return const SyncExecutionResult(success: true);
  }

  @override
  Future<List<BatchSyncExecutionResult>> syncItems(
    List<PendingSyncItem> items,
  ) async {
    final results = <BatchSyncExecutionResult>[];
    for (final item in items) {
      final single = await syncItem(item);
      results.add(
        BatchSyncExecutionResult(
          clientUuid: item.clientUuid,
          success: single.success,
          conflict: single.conflict,
          blocked: false,
          errorMessage: single.errorMessage,
        ),
      );
    }
    return results;
  }
}
