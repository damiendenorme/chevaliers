import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/main.dart';

void main() {
  testWidgets('Top bar shows the player count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MyHomePage(loadPlayerCount: () async => 42)),
    );

    // Pendant le chargement : un tiret.
    expect(find.text('–'), findsOneWidget);

    await tester.pump();

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });
}
