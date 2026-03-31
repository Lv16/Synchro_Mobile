import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundSyncNotificationService {
  BackgroundSyncNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'rdo_sync_status',
    'Sincronização de RDO',
    description:
        'Notificações sobre envio automático de RDOs em segundo plano.',
    importance: Importance.high,
  );

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize({bool requestPermission = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (!_initialized) {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const settings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings: settings);

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_channel);
      _initialized = true;
    }

    if (requestPermission) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  static Future<void> requestPermissionIfNeeded() async {
    await initialize(requestPermission: true);
  }

  static Future<void> showSyncSuccess({
    required int rdoCount,
    required int operationCount,
    String lead = 'A sincronização automática',
  }) async {
    if (rdoCount <= 0 || operationCount <= 0) {
      return;
    }

    await initialize();

    final title = rdoCount == 1
        ? 'RDO enviado com sucesso'
        : '$rdoCount RDOs enviados com sucesso';
    final body = rdoCount == 1
        ? '$lead concluiu $operationCount etapa(s) deste RDO.'
        : '$lead concluiu $operationCount etapa(s) em $rdoCount RDOs.';

    const androidDetails = AndroidNotificationDetails(
      'rdo_sync_status',
      'Sincronização de RDO',
      channelDescription:
          'Notificações sobre envio automático de RDOs em segundo plano.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showBackgroundSyncSuccess({
    required int rdoCount,
    required int operationCount,
  }) async {
    await showSyncSuccess(
      rdoCount: rdoCount,
      operationCount: operationCount,
      lead: 'O envio automático',
    );
  }
}
