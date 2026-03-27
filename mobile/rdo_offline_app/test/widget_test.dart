import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:rdo_offline_app/src/features/rdo/data/demo_rdo_sync_gateway.dart';
import 'package:rdo_offline_app/src/features/rdo/data/in_memory_offline_rdo_repository.dart';
import 'package:rdo_offline_app/src/features/home/presentation/home_page.dart';

void main() {
  testWidgets('home renders queue actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          repository: InMemoryOfflineRdoRepository(),
          syncGateway: DemoRdoSyncGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RDOs no aparelho'), findsOneWidget);
    expect(find.text('Gerar fila demo'), findsOneWidget);
    expect(find.text('Sincronizar agora'), findsOneWidget);
  });
}
