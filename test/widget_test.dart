import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/rows.dart';
import 'package:chevaliers/main.dart';
import 'package:chevaliers/widgets/row_list.dart';
import 'package:chevaliers/widgets/section_buttons.dart';
import 'package:chevaliers/widgets/top_bar.dart';

void main() {
  testWidgets('No header or footer; the table scrolls, not the screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => RowTable(
            columns: const ['Nom'],
            rows: [
              for (var i = 0; i < 100; i++) ['Joueur $i'],
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Les Chevaliers'), findsNothing);
    expect(find.text('Discord'), findsNothing);

    final screen = tester.getRect(find.byType(MyHomePage));
    await tester.tap(find.byType(SectionButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Joueur 0'), findsOneWidget);

    // Barre des boutons à 12 + 52px du haut de l'écran ; pied du tableau à
    // la même distance du bas.
    final barTop = tester.getRect(find.byType(SectionBar)).top;
    final buttonsTop = tester.getRect(find.byType(SectionButton).first).top;
    final tableBox = tester.getRect(find.byType(RowList));
    expect(barTop, screen.top + 12 + 52);
    expect(screen.bottom - tableBox.bottom, barTop - screen.top);

    // C'est la liste qui défile, pas l'écran.
    final firstRowBefore = tester.getRect(find.text('Joueur 0')).top;
    await tester.drag(find.text('Joueur 0'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Joueur 0')).top, lessThan(firstRowBefore));
    expect(tester.getRect(find.byType(RowList)), tableBox);
    expect(tester.getRect(find.byType(SectionButton).first).top, buttonsTop);
  });

  testWidgets('Label buttons form a horizontal row above the tables', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(columns: ['Nom'], rows: []),
        ),
      ),
    );
    await tester.pump();

    final buttons = find.byType(SectionButton);
    expect(buttons, findsNWidgets(4));

    final rects = [for (var i = 0; i < 4; i++) tester.getRect(buttons.at(i))];
    const labels = ['Joueurs', 'Événements', 'Parties', 'Jeux'];
    expect(find.byType(Icon), findsNothing);
    for (var i = 0; i < 4; i++) {
      expect(
        find.descendant(of: buttons.at(i), matching: find.text(labels[i])),
        findsOneWidget,
      );
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
          loadRows: (table) async {
            requested.add(table);
            return switch (table) {
              'joueur' => const RowTable(
                columns: ['Nom', 'Jeu favori'],
                rows: [
                  ['Arthur', 'Dames'],
                  ['Lancelot', 'Échecs'],
                ],
              ),
              'partie' => const RowTable(
                matchups: [
                  (
                    player1: 'Arthur',
                    score1: 3,
                    score2: 2,
                    player2: 'Lancelot',
                  ),
                ],
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
    // Au démarrage : la liste des parties, son bouton actif.
    // Bouton actif : fond bleu et texte blanc, comme la ligne choisie de la
    // liste.
    bool isActive(String label) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byType(SectionButton),
      );
      final material = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      final text = tester.widget<Text>(find.text(label));
      return material.color == accentColor && text.style?.color == Colors.white;
    }

    expect(isActive('Parties'), isTrue);
    expect(isActive('Joueurs'), isFalse);
    expect(requested, ['partie']);
    expect(find.text('–'), findsOneWidget);
    expect(find.text('Lancelot'), findsOneWidget);

    final buttons = find.byType(SectionButton);

    await tester.tap(buttons.at(0));
    await tester.pumpAndSettle();
    expect(isActive('Joueurs'), isTrue);
    expect(isActive('Parties'), isFalse);
    // La liste à gauche ; rien à droite tant qu'aucune ligne n'est choisie.
    expect(find.text('Arthur'), findsOneWidget);
    expect(find.text('Lancelot'), findsOneWidget);
    expect(find.text('Jeu favori'), findsNothing);
    // Zone de 1000px, centrée horizontalement.
    final playersTable = tester.getRect(find.byType(RowList));
    expect(playersTable.width, 1000);
    expect(playersTable.center.dx, moreOrLessEquals(1400 / 2));
    expect(tester.getRect(find.text('Arthur')).left, playersTable.left + 12);

    // Au clic sur une ligne, son détail s'affiche à droite de la liste.
    await tester.tap(find.text('Lancelot'));
    await tester.pumpAndSettle();
    // En liste : le nom de l'information, puis sa valeur dessous. Le nom du
    // joueur n'est pas repris.
    expect(find.byType(Table), findsNothing);
    expect(find.text('Nom'), findsNothing);
    expect(find.text('Lancelot'), findsOneWidget);
    final label = tester.getRect(find.text('Jeu favori'));
    final value = tester.getRect(find.text('Échecs'));
    expect(
      label.left,
      greaterThanOrEqualTo(playersTable.left + RowList.listWidth),
    );
    expect(value.left, label.left);
    expect(value.top, greaterThanOrEqualTo(label.bottom));
    // Bannière de 160px en haut du détail, sur toute sa largeur.
    expect(label.top, greaterThanOrEqualTo(playersTable.top + 160));

    // Barre blanche des boutons alignée sur les bords des deux cartes,
    // restée à sa place (52px + 12px sous le haut de l'écran) ; boutons
    // centrés dedans.
    final bar = tester.getRect(find.byType(SectionBar));
    expect(bar.left, playersTable.left);
    expect(bar.right, playersTable.right);
    expect(bar.top, 12 + 52);
    final firstButton = tester.getRect(buttons.at(0));
    final lastButton = tester.getRect(buttons.at(3));
    expect(
      (firstButton.left + lastButton.right) / 2,
      moreOrLessEquals(playersTable.center.dx),
    );
    expect(firstButton.top, bar.top + SectionBar.padding);
    expect(firstButton.bottom, bar.bottom - SectionBar.padding);
    // Tableau sous la barre, au même écart qu'entre les deux cartes.
    expect(playersTable.top - bar.bottom, RowList.gap);

    // Changer de table vide le détail.
    await tester.tap(buttons.at(2));
    await tester.pumpAndSettle();
    // Joueur 1 à gauche, scores au milieu, joueur 2 à droite de la liste.
    final p1 = tester.getRect(find.text('Arthur'));
    final scores = tester.getRect(find.text('–'));
    final p2 = tester.getRect(find.text('Lancelot'));
    expect(p1.left, playersTable.left + 12);
    expect(
      scores.center.dx,
      moreOrLessEquals(playersTable.left + RowList.listWidth / 2),
    );
    expect(p2.right, playersTable.left + RowList.listWidth - 12);
    expect(scores.center.dy, p1.center.dy);
    expect(p2.center.dy, p1.center.dy);
    expect(find.text('Score 1'), findsNothing);
    // Gagnant et son score en gras, perdant et son score grisés.
    FontWeight? weight(String t) =>
        tester.widget<Text>(find.text(t)).style?.fontWeight;
    double? alpha(String t) =>
        tester.widget<Text>(find.text(t)).style?.color?.a;
    expect(weight('Arthur'), FontWeight.bold);
    expect(weight('3'), FontWeight.bold);
    expect(weight('Lancelot'), isNot(FontWeight.bold));
    expect(weight('2'), isNot(FontWeight.bold));
    expect(alpha('Lancelot'), lessThan(1));
    expect(alpha('2'), lessThan(1));
    expect(alpha('Arthur') ?? 1, 1);
    await tester.tap(find.text('–'));
    await tester.pumpAndSettle();
    expect(find.text('Score 1'), findsOneWidget);
    expect(find.text('Échecs'), findsOneWidget);
    // Le score : dans la liste et dans le détail.
    expect(find.text('3'), findsNWidgets(2));

    // Même emplacement et même largeur, quel que soit le contenu.
    final gamesTable = tester.getRect(find.byType(RowList));
    expect(gamesTable, playersTable);

    await tester.tap(buttons.at(3));
    await tester.pumpAndSettle();
    expect(find.text('Aucune ligne.'), findsOneWidget);

    expect(requested, ['partie', 'joueur', 'partie', 'jeu']);
  });

  testWidgets('A game detail ranks players in a list like the master one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(
            columns: ['Nom'],
            rows: [
              ['Échecs'],
            ],
            badges: [2],
            lists: [
              [('1. Arthur', '105'), ('2. Lancelot', '95')],
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(SectionButton).at(3));
    await tester.pumpAndSettle();
    // Pastille du nombre de joueurs, à droite de la ligne, sans la grandir.
    final row = tester.getRect(find.text('Échecs'));
    final badge = tester.getRect(find.text('2'));
    final listRight =
        tester.getRect(find.byType(RowList)).left + RowList.listWidth;
    expect(badge.right, greaterThan(listRight - 12 - 20));
    expect(badge.right, lessThanOrEqualTo(listRight - 12));
    expect(badge.center.dy, moreOrLessEquals(row.center.dy, epsilon: 1));

    await tester.tap(find.text('Échecs'));
    await tester.pumpAndSettle();

    final master = tester.getRect(find.text('Échecs'));
    final first = tester.getRect(find.text('1. Arthur'));
    final firstValue = tester.getRect(find.text('105'));
    final second = tester.getRect(find.text('2. Lancelot'));
    // Une ligne par joueur : rang et nom à gauche, ELO à droite, sur la même
    // ligne ; même hauteur de ligne que la liste de gauche.
    expect(firstValue.center.dy, first.center.dy);
    expect(firstValue.left, greaterThanOrEqualTo(first.right));
    expect(firstValue.right, tester.getRect(find.byType(RowList)).right - 12);
    expect(second.top - first.top, master.height + 8);
    expect(find.text('Nom'), findsNothing);
  });

  testWidgets('Hovering a button does not animate or resize it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SectionButton(label: 'Joueurs', onPressed: () {}),
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
    expect(find.text('Joueurs'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(AnimatedSize), findsNothing);
  });
}
