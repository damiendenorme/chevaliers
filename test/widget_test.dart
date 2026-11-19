import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/rows.dart';
import 'package:chevaliers/main.dart';
import 'package:chevaliers/widgets/section_buttons.dart';
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

  testWidgets('Round buttons form a horizontal row above the tables', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadPlayerCount: () async => 0,
          loadEventCount: () async => 0,
          loadGameCount: () async => 0,
          loadBoardGameCount: () async => 0,
          loadRows: (_) async => const RowTable(columns: ['Nom'], rows: []),
        ),
      ),
    );
    await tester.pump();

    final buttons = find.byType(SectionButton);
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
      expect(rects[i].width, rects[i].height);
      expect(rects[i].top, rects[0].top);
      if (i > 0) expect(rects[i].left, greaterThan(rects[i - 1].right));
    }
  });

  testWidgets('Clicking a button lists the rows of its table', (tester) async {
    // Écran plus large que le tableau (1000px).
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final requested = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadPlayerCount: () async => 0,
          loadEventCount: () async => 0,
          loadGameCount: () async => 0,
          loadBoardGameCount: () async => 0,
          loadRows: (table) async {
            requested.add(table);
            return switch (table) {
              'joueur' => const RowTable(
                columns: ['Nom'],
                rows: [
                  ['Arthur'],
                  ['Lancelot'],
                ],
              ),
              'partie' => const RowTable(
                columns: ['Joueur 1', 'Score 1', 'Score 2', 'Joueur 2', 'Jeu'],
                rows: [
                  ['Arthur', '3', '2', 'Lancelot', 'Échecs'],
                ],
              ),
              _ => const RowTable(columns: ['Nom'], rows: []),
            };
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Arthur'), findsNothing);

    final buttons = find.byType(SectionButton);

    await tester.tap(buttons.at(0));
    await tester.pumpAndSettle();
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Arthur'), findsOneWidget);
    expect(find.text('Lancelot'), findsOneWidget);
    // Tableau de 1000px, centré horizontalement.
    final playersTable = tester.getRect(find.byType(Table));
    final barBottom = tester.getRect(find.byType(TopBar)).bottom;
    expect(playersTable.width, 1000);
    expect(playersTable.center.dx, moreOrLessEquals(1400 / 2));

    // Boutons centrés sur le tableau, restés à leur place (52px + 12px sous
    // la barre).
    final firstButton = tester.getRect(buttons.at(0));
    final lastButton = tester.getRect(buttons.at(3));
    expect(
      (firstButton.left + lastButton.right) / 2,
      moreOrLessEquals(playersTable.center.dx),
    );
    expect(firstButton.top, barBottom + 12 + 52);
    // Tableau 20px sous les boutons.
    expect(playersTable.top - firstButton.bottom, 20);

    await tester.tap(buttons.at(2));
    await tester.pumpAndSettle();
    expect(find.text('Lancelot'), findsOneWidget);
    expect(find.text('Score 1'), findsOneWidget);
    expect(find.text('Échecs'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // Même emplacement et même largeur, quel que soit le contenu.
    final gamesTable = tester.getRect(find.byType(Table));
    expect(gamesTable.topLeft, playersTable.topLeft);
    expect(gamesTable.width, playersTable.width);

    await tester.tap(buttons.at(3));
    await tester.pumpAndSettle();
    expect(find.text('Aucune ligne.'), findsOneWidget);

    expect(requested, ['joueur', 'partie', 'jeu']);
  });

  testWidgets('Hovering a button does not animate it or show its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SectionButton(
              icon: Icons.person,
              label: 'Joueurs',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final button = find.byType(SectionButton);
    final before = tester.getRect(button);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: before.center);
    await tester.pump();

    expect(tester.getRect(button), before);
    expect(find.text('Joueurs'), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(AnimatedSize), findsNothing);
  });
}
