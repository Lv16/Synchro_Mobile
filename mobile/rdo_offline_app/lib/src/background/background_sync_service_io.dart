import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'background_sync_notification_service.dart';
import 'background_sync_telemetry.dart';
import '../features/auth/data/shared_prefs_auth_session_store.dart';
import '../features/rdo/application/offline_sync_controller.dart';
import '../features/rdo/data/http_rdo_sync_gateway.dart';
import '../features/rdo/data/sqlite_offline_rdo_repository.dart';

@pragma('vm:entry-point')
void rdoBackgroundSyncDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != BackgroundSyncService.taskName &&
        taskName != BackgroundSyncService.oneOffTaskName) {
      return true;
    }

    final source = (inputData?['source'] as String?)?.trim().isNotEmpty == true
        ? (inputData!['source'] as String).trim()
        : 'android_background';

    await BackgroundSyncTelemetry.save(
      source: source,
      status: 'running',
      outcome: 'Sincronização automática iniciada.',
    );

    try {
      await BackgroundSyncNotificationService.initialize();
      return await _BackgroundSyncRunner(source: source).run();
    } catch (err) {
      await BackgroundSyncTelemetry.save(
        source: source,
        status: 'error',
        outcome: 'Falha inesperada no worker: $err',
      );
      return false;
    }
  });
}

class BackgroundSyncService {
  static const String taskName = 'rdo_background_sync_task';
  static const String oneOffTaskName = 'rdo_background_sync_oneoff_task';
  static const String _uniqueName = 'rdo_background_sync_periodic';
  static const String _oneOffUniqueName = 'rdo_background_sync_oneoff';
  static const Duration _frequency = Duration(minutes: 15);
  static const Duration _initialDelay = Duration(minutes: 1);
  static const Duration _backoffDelay = Duration(minutes: 5);
  static const Duration _oneOffInitialDelay = Duration(seconds: 10);

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      _initialized = true;
      return;
    }

    await Workmanager().initialize(rdoBackgroundSyncDispatcher);

    await Workmanager().registerPeriodicTask(
      _uniqueName,
      taskName,
      frequency: _frequency,
      initialDelay: _initialDelay,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: _backoffDelay,
      inputData: const <String, dynamic>{
        'source': 'android_background_periodic',
      },
    );

    _initialized = true;
  }

  static Future<void> scheduleImmediateSync({String reason = 'manual'}) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await initialize();

    final normalizedReason = reason.trim().isEmpty ? 'manual' : reason.trim();
    await Workmanager().registerOneOffTask(
      _oneOffUniqueName,
      oneOffTaskName,
      initialDelay: _oneOffInitialDelay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: _backoffDelay,
      inputData: <String, dynamic>{
        'source': 'android_background_$normalizedReason',
      },
    );
  }
}

class _BackgroundSyncRunner {
  _BackgroundSyncRunner({required String source}) : _source = source;

  static const String _syncUrlEnv = String.fromEnvironment(
    'RDO_SYNC_URL',
    defaultValue: '',
  );
  static const String _photoUploadUrlEnv = String.fromEnvironment(
    'RDO_PHOTO_UPLOAD_URL',
    defaultValue: '',
  );
  static const String _syncBatchUrlEnv = String.fromEnvironment(
    'RDO_SYNC_BATCH_URL',
    defaultValue: '',
  );
  static const String _apiTokenEnv = String.fromEnvironment(
    'RDO_API_TOKEN',
    defaultValue: '',
  );

  final String _source;

  Future<bool> run() async {
    final syncUrl = _resolveSyncUrl();
    if (syncUrl == null) {
      await BackgroundSyncTelemetry.save(
        source: _source,
        status: 'skipped',
        outcome: 'RDO_SYNC_URL não configurada no build.',
      );
      return true;
    }

    final authStore = const SharedPrefsAuthSessionStore();
    final staticHeaders = <String, String>{};
    final staticToken = _apiTokenEnv.trim();
    final session = await authStore.read();
    final hasValidSession =
        session != null &&
        !session.isExpired &&
        session.accessToken.trim().isNotEmpty;
    if (staticToken.isNotEmpty) {
      staticHeaders['Authorization'] = 'Bearer $staticToken';
    }
    if (staticToken.isEmpty && !hasValidSession) {
      await BackgroundSyncTelemetry.save(
        source: _source,
        status: 'skipped',
        outcome: 'Sem sessão válida para sincronizar em segundo plano.',
      );
      return true;
    }

    final syncGateway = HttpRdoSyncGateway(
      syncUrl: syncUrl,
      batchSyncUrl: _parseOptionalUri(_syncBatchUrlEnv),
      photoUploadUrl: _resolvePhotoUploadUrl(syncUrl),
      staticHeaders: staticHeaders,
      authTokenProvider: () async {
        if (staticToken.isNotEmpty) {
          return null;
        }
        final currentSession = await authStore.read();
        if (currentSession == null || currentSession.isExpired) {
          return null;
        }
        final token = currentSession.accessToken.trim();
        if (token.isEmpty) {
          return null;
        }
        return token;
      },
    );

    final repository = SqliteOfflineRdoRepository();
    final controller = OfflineSyncController(repository, syncGateway);
    await controller.loadQueue();
    if (controller.queuedCount <= 0) {
      await BackgroundSyncTelemetry.save(
        source: _source,
        status: 'success',
        outcome: 'Sem itens pendentes para envio.',
        queuedCount: 0,
        errorCount: 0,
      );
      return true;
    }

    await controller.syncQueuedItems();
    await controller.loadQueue();

    final queued = controller.queuedCount;
    final errors = controller.errorCount;
    final successfulRdos = controller.lastRoundSuccessRdoCount;
    final successfulOperations = controller.lastRoundSuccessCount;
    if (errors > 0) {
      await BackgroundSyncTelemetry.save(
        source: _source,
        status: 'error',
        outcome: controller.message ?? 'Sincronização em background com erro.',
        queuedCount: queued,
        errorCount: errors,
      );
      return false;
    }
    if (queued > 0) {
      await BackgroundSyncTelemetry.save(
        source: _source,
        status: 'partial',
        outcome:
            controller.message ??
            'Sincronização em background parcialmente concluída.',
        queuedCount: queued,
        errorCount: 0,
      );
      return true;
    }

    if (successfulRdos > 0 && successfulOperations > 0) {
      await BackgroundSyncNotificationService.showBackgroundSyncSuccess(
        rdoCount: successfulRdos,
        operationCount: successfulOperations,
      );
    }

    await BackgroundSyncTelemetry.save(
      source: _source,
      status: 'success',
      outcome: controller.message ?? 'Sincronização em background concluída.',
      queuedCount: 0,
      errorCount: 0,
    );
    return true;
  }

  Uri? _resolveSyncUrl() {
    final rawSyncUrl = _syncUrlEnv.trim();
    if (rawSyncUrl.isEmpty) {
      return null;
    }
    try {
      return Uri.parse(rawSyncUrl);
    } catch (_) {
      return null;
    }
  }

  Uri? _resolvePhotoUploadUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(_photoUploadUrlEnv);
    if (configured != null) {
      return configured;
    }
    return _deriveFromSync(syncUrl, '/photo/upload/');
  }

  Uri? _deriveFromSync(Uri syncUrl, String replacementSuffix) {
    const marker = '/rdo/sync';
    final path = syncUrl.path;
    final markerIndex = path.indexOf(marker);
    if (markerIndex < 0) {
      return null;
    }
    final prefix = path.substring(0, markerIndex);
    return syncUrl.replace(path: '$prefix$replacementSuffix');
  }

  Uri? _parseOptionalUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    try {
      return Uri.parse(value);
    } catch (_) {
      return null;
    }
  }
}
