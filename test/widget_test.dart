import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/main.dart';

void main() {
  testWidgets('Top bar shows player count, then event count on its right', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadPlayerCount: () async => 42,
          loadEventCount: () async => 3,
        ),
      ),
    );

    // Pendant le chargement : un tiret par compteur.
    expect(find.text('–'), findsNWidgets(2));

    await tester.pump();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.confirmation_number), findsOneWidget);
    expect(
      tester.getCenter(find.text('3')).dx,
      greaterThan(tester.getCenter(find.text('42')).dx),
    );
  });
}
