import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BackgroundSyncSnapshot {
  const BackgroundSyncSnapshot({
    required this.at,
    required this.source,
    required this.status,
    required this.outcome,
    this.queuedCount,
    this.errorCount,
  });

  final DateTime at;
  final String source;
  final String status;
  final String outcome;
  final int? queuedCount;
  final int? errorCount;

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';
  bool get isPartial => status == 'partial';
  bool get isSkipped => status == 'skipped';

  String get sourceLabel {
    switch (source) {
      case 'android_background_periodic':
        return 'Android em segundo plano';
      default:
        return source.trim().isEmpty ? 'Background' : source.trim();
    }
  }
}

class BackgroundSyncTelemetry {
  const BackgroundSyncTelemetry._();

  static const String storageKey = 'rdo.mobile.background_sync.status.v1';

  static Future<void> save({
    required String source,
    required String status,
    required String outcome,
    int? queuedCount,
    int? errorCount,
    DateTime? at,
  }) async {
    final snapshotMap = <String, dynamic>{
      'at': (at ?? DateTime.now()).toIso8601String(),
      'source': source.trim(),
      'status': status.trim(),
      'outcome': outcome.trim(),
      'queued_count': queuedCount,
      'error_count': errorCount,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(snapshotMap));
  }

  static Future<BackgroundSyncSnapshot?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final at = DateTime.tryParse('${decoded['at'] ?? ''}');
      if (at == null) {
        return null;
      }
      final source = ('${decoded['source'] ?? ''}').trim();
      final status = ('${decoded['status'] ?? ''}').trim();
      final outcome = ('${decoded['outcome'] ?? ''}').trim();
      if (status.isEmpty) {
        return null;
      }
      return BackgroundSyncSnapshot(
        at: at,
        source: source,
        status: status,
        outcome: outcome,
        queuedCount: _coerceInt(decoded['queued_count']),
        errorCount: _coerceInt(decoded['error_count']),
      );
    } catch (_) {
      return null;
    }
  }
}

int? _coerceInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
