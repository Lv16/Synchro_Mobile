import 'dart:convert';

enum SyncState { draft, queued, syncing, synced, error, conflict }

SyncState syncStateFromStorage(String raw) {
  for (final state in SyncState.values) {
    if (state.name == raw) {
      return state;
    }
  }
  return SyncState.queued;
}

class PendingSyncItem {
  const PendingSyncItem({
    required this.clientUuid,
    required this.operation,
    required this.osNumber,
    required this.rdoSequence,
    required this.businessDate,
    required this.payload,
    required this.state,
    this.localId,
    this.retryCount = 0,
    this.lastError,
    this.createdAt,
    this.updatedAt,
  });

  final int? localId;
  final String clientUuid;
  final String operation;
  final String osNumber;
  final int rdoSequence;
  final DateTime businessDate;
  final Map<String, dynamic> payload;
  final SyncState state;
  final int retryCount;
  final String? lastError;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PendingSyncItem copyWith({
    int? localId,
    String? clientUuid,
    String? operation,
    String? osNumber,
    int? rdoSequence,
    DateTime? businessDate,
    Map<String, dynamic>? payload,
    SyncState? state,
    int? retryCount,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearLastError = false,
  }) {
    return PendingSyncItem(
      localId: localId ?? this.localId,
      clientUuid: clientUuid ?? this.clientUuid,
      operation: operation ?? this.operation,
      osNumber: osNumber ?? this.osNumber,
      rdoSequence: rdoSequence ?? this.rdoSequence,
      businessDate: businessDate ?? this.businessDate,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toDbMap() {
    return <String, dynamic>{
      'id': localId,
      'client_uuid': clientUuid,
      'operation': operation,
      'os_number': osNumber,
      'rdo_sequence': rdoSequence,
      'business_date': businessDate.toIso8601String(),
      'payload_json': jsonEncode(payload),
      'state': state.name,
      'retry_count': retryCount,
      'last_error': lastError,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory PendingSyncItem.fromDbMap(Map<String, dynamic> row) {
    Map<String, dynamic> parsedPayload = <String, dynamic>{};
    final rawPayload = row['payload_json'];
    if (rawPayload is String && rawPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map<String, dynamic>) {
          parsedPayload = decoded;
        }
      } catch (_) {
        parsedPayload = <String, dynamic>{};
      }
    }

    DateTime? parseDate(String key) {
      final raw = row[key];
      if (raw is! String || raw.isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw);
    }

    return PendingSyncItem(
      localId: row['id'] is int
          ? row['id'] as int
          : int.tryParse('${row['id']}'),
      clientUuid: '${row['client_uuid'] ?? ''}',
      operation: '${row['operation'] ?? 'rdo.update'}',
      osNumber: '${row['os_number'] ?? ''}',
      rdoSequence:
          (row['rdo_sequence'] as int?) ??
          int.tryParse('${row['rdo_sequence']}') ??
          0,
      businessDate:
          DateTime.tryParse('${row['business_date'] ?? ''}') ?? DateTime.now(),
      payload: parsedPayload,
      state: syncStateFromStorage('${row['state'] ?? SyncState.queued.name}'),
      retryCount:
          (row['retry_count'] as int?) ??
          int.tryParse('${row['retry_count']}') ??
          0,
      lastError: row['last_error']?.toString(),
      createdAt: parseDate('created_at'),
      updatedAt: parseDate('updated_at'),
    );
  }
}
