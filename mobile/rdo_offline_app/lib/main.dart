import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/background/background_sync_notification_service.dart';
import 'src/background/background_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundSyncNotificationService.initialize();
  await BackgroundSyncService.initialize();
  runApp(const RdoOfflineApp());
}
