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
          loadGameCount: () async => 5,
          loadBoardGameCount: () async => 8,
        ),
      ),
    );

    // Pendant le chargement : un tiret par compteur.
    expect(find.text('–'), findsNWidgets(4));

    await tester.pump();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.confirmation_number), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsOneWidget);
    expect(
      tester.getCenter(find.text('3')).dx,
      greaterThan(tester.getCenter(find.text('42')).dx),
    );
    expect(
      tester.getCenter(find.text('5')).dx,
      greaterThan(tester.getCenter(find.text('3')).dx),
    );
    expect(
      tester.getCenter(find.text('8')).dx,
      greaterThan(tester.getCenter(find.text('5')).dx),
    );
  });
}
