import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/main.dart';
import 'package:chevaliers/widgets/side_buttons.dart';
import 'package:chevaliers/widgets/top_bar.dart';

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

    Finder inBar(IconData icon) =>
        find.descendant(of: find.byType(TopBar), matching: find.byIcon(icon));

    // Pendant le chargement : un tiret par compteur.
    expect(find.text('–'), findsNWidgets(4));

    await tester.pump();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(inBar(Icons.person), findsOneWidget);
    expect(inBar(Icons.confirmation_number), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(inBar(Icons.flag), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(inBar(Icons.casino), findsOneWidget);
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

    // Titre à gauche de la barre.
    final title = tester.getRect(find.text('Les Chevaliers'));
    expect(title.left, lessThan(50));
    expect(title.right, lessThan(tester.getRect(inBar(Icons.person)).left));

    // « Discord » à droite de la barre.
    final discord = tester.getRect(find.text('Discord'));
    expect(
      discord.right,
      greaterThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio - 50,
      ),
    );
    expect(
      discord.left,
      greaterThan(tester.getRect(inBar(Icons.casino)).right),
    );
  });

  testWidgets('Round buttons are stacked top to bottom on the left', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadPlayerCount: () async => 0,
          loadEventCount: () async => 0,
          loadGameCount: () async => 0,
          loadBoardGameCount: () async => 0,
        ),
      ),
    );
    await tester.pump();

    final buttons = find.byType(SideButton);
    expect(buttons, findsNWidgets(4));

    final rects = [for (var i = 0; i < 4; i++) tester.getRect(buttons.at(i))];
    final icons = [
      Icons.person,
      Icons.confirmation_number,
      Icons.flag,
      Icons.casino,
    ];
    for (var i = 0; i < 4; i++) {
      expect(
        find.descendant(of: buttons.at(i), matching: find.byIcon(icons[i])),
        findsOneWidget,
      );
      expect(rects[i].left, lessThan(50));
      expect(rects[i].width, rects[i].height);
      if (i > 0) expect(rects[i].top, greaterThan(rects[i - 1].bottom));
    }
  });

  testWidgets('Hovering a side button stretches it right to show its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SideButton(
              icon: Icons.person,
              label: 'Joueurs',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final button = find.byType(SideButton);
    final collapsed = tester.getRect(button);
    expect(find.text('Joueurs'), findsNothing);
    expect(find.byType(Tooltip), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: collapsed.center);
    await tester.pumpAndSettle();

    final expanded = tester.getRect(button);
    expect(find.text('Joueurs'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(expanded.left, collapsed.left);
    expect(expanded.width, greaterThan(collapsed.width));
    expect(expanded.height, collapsed.height);

    await mouse.moveTo(const Offset(600, 500));
    await tester.pumpAndSettle();
    expect(find.text('Joueurs'), findsNothing);
    expect(tester.getRect(button).width, collapsed.width);
  });
}
