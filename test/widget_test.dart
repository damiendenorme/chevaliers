import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/rows.dart';
import 'package:chevaliers/main.dart';
import 'package:chevaliers/widgets/row_list.dart';
import 'package:chevaliers/widgets/section_buttons.dart';
import 'package:chevaliers/widgets/top_bar.dart';

/// Texte [t] dans la carte des listes (hors encoche du haut de l'écran).
Finder inList(String t) =>
    find.descendant(of: find.byType(RowList), matching: find.text(t));

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
    expect(
      find.descendant(of: buttons, matching: find.byType(Icon)),
      findsNothing,
    );
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
    // Bouton actif : fond texturé doré et texte blanc, comme la ligne
    // choisie de la liste.
    bool isActive(String label) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byType(SectionButton),
      );
      final ink = tester.widget<Ink>(
        find.descendant(of: button, matching: find.byType(Ink)).first,
      );
      final text = tester.widget<Text>(find.text(label));
      return ink.decoration == accentTexture &&
          text.style?.color == Colors.white;
    }

    expect(isActive('Parties'), isTrue);
    expect(isActive('Joueurs'), isFalse);
    expect(requested, ['partie']);
    expect(inList('–'), findsOneWidget);
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
    final scores = tester.getRect(inList('–'));
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
    await tester.tap(inList('–'));
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
    // « Nom » : seulement dans l'en-tête de la liste, pas dans le détail.
    expect(find.text('Nom'), findsOneWidget);
    expect(
      tester.getRect(find.text('Nom')).right,
      lessThan(tester.getRect(find.byType(RowList)).left + RowList.listWidth),
    );
  });

  testWidgets('The games list sorts by name or number of players', (
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
              ['Dames'],
              ['Échecs'],
              ['Go'],
            ],
            badges: [5, 2, 7],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(SectionButton).at(3));
    await tester.pumpAndSettle();

    List<String> order() => ['Dames', 'Échecs', 'Go']
      ..sort(
        (a, b) => tester
            .getRect(find.text(a))
            .top
            .compareTo(tester.getRect(find.text(b)).top),
      );
    final playersHeader = find.descendant(
      of: find.byType(RowList),
      matching: find.text('Joueurs'),
    );

    // Par nom au départ.
    expect(order(), ['Dames', 'Échecs', 'Go']);
    // Par nombre de joueurs : du plus grand au plus petit, puis l'inverse.
    await tester.tap(playersHeader);
    await tester.pump();
    expect(order(), ['Go', 'Dames', 'Échecs']);
    await tester.tap(playersHeader);
    await tester.pump();
    expect(order(), ['Échecs', 'Dames', 'Go']);
    // Retour au nom.
    await tester.tap(find.text('Nom'));
    await tester.pump();
    expect(order(), ['Dames', 'Échecs', 'Go']);
  });

  testWidgets('The players list header sorts by name or score', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => RowTable(
            columns: ['Nom'],
            rows: [
              ['Arthur'],
              ['Bors'],
              ['Gauvain'],
              ['Lancelot'],
            ],
            forms: [[], [], [], []],
            globalScores: [98, 107, null, 112],
            sortableLists: true,
            listForms: [
              [
                [Outcome.win],
                [Outcome.loss, Outcome.loss],
              ],
              [],
              [],
              [],
            ],
            lists: [
              [('Échecs', '104'), ('Dames', '92')],
              [],
              [],
              [],
            ],
            matchLists: [
              [
                (
                  date: DateTime(2026, 11, 21),
                  matchup: (
                    player1: 'Arthur',
                    score1: 7,
                    score2: 9,
                    player2: 'Bors',
                  ),
                  game: 'Go',
                  place: 'Aumes',
                  eloDelta1: -4.62,
                  form1: const [],
                  form2: const [],
                ),
                (
                  date: DateTime(2026, 11, 3),
                  matchup: (
                    player1: 'Arthur',
                    score1: 5,
                    score2: 1,
                    player2: 'Lancelot',
                  ),
                  game: 'Awalé',
                  place: 'Frontignan',
                  eloDelta1: 3,
                  form1: const [],
                  form2: const [],
                ),
              ],
              [],
              [],
              [],
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    List<String> order() {
      final names = ['Arthur', 'Bors', 'Gauvain', 'Lancelot'];
      return names..sort(
        (a, b) => tester
            .getRect(find.text(a))
            .top
            .compareTo(tester.getRect(find.text(b)).top),
      );
    }

    // Au départ, par score : du meilleur au moins bon, sans score en dernier.
    expect(order(), ['Lancelot', 'Bors', 'Arthur', 'Gauvain']);
    expect(
      tester.getRect(find.text('Score')).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Lancelot')).top),
    );

    // Clic sur « Score » : sens inverse, sans score toujours en dernier.
    await tester.tap(find.text('Score'));
    await tester.pump();
    expect(order(), ['Arthur', 'Bors', 'Lancelot', 'Gauvain']);

    // Retour au tri par nom, de A à Z, puis de Z à A.
    await tester.tap(find.text('Nom'));
    await tester.pump();
    expect(order(), ['Arthur', 'Bors', 'Gauvain', 'Lancelot']);
    await tester.tap(find.text('Nom'));
    await tester.pump();
    expect(order(), ['Lancelot', 'Gauvain', 'Bors', 'Arthur']);

    // Détail : ses jeux, puis ses parties dessous, au format de la liste.
    await tester.tap(find.text('Arthur'));
    await tester.pump();
    final partiesTitle = find.descendant(
      of: find.byType(RowList),
      matching: find.text('Parties'),
    );
    expect(partiesTitle, findsOneWidget);
    final game = tester.getRect(find.text('Échecs'));
    final title = tester.getRect(partiesTitle);
    final score = tester.getRect(find.text('7'));
    expect(title.top, greaterThan(game.bottom));
    expect(score.top, greaterThan(title.bottom));
    expect(find.text('Bors'), findsNWidgets(2));

    // Parties : par date au départ, puis triables par jeu ou par lieu.
    double y(String t) => tester.getRect(find.text(t).last).top;
    expect(y('Go'), lessThan(y('Awalé')));
    await tester.tap(find.text('Jeu'));
    await tester.pump();
    expect(y('Awalé'), lessThan(y('Go')));
    await tester.tap(find.text('Jeu'));
    await tester.pump();
    expect(y('Go'), lessThan(y('Awalé')));
    await tester.tap(find.text('Lieu'));
    await tester.pump();
    expect(y('Aumes'), lessThan(y('Frontignan')));
    await tester.tap(find.text('Lieu'));
    await tester.pump();
    expect(y('Frontignan'), lessThan(y('Aumes')));
    // Par date : de la plus récente à la plus ancienne, puis l'inverse.
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(y('21/11/26'), lessThan(y('03/11/26')));
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(y('03/11/26'), lessThan(y('21/11/26')));

    // Le jeu à gauche du joueur 1, le lieu à droite du joueur 2, et
    // l'évolution du ELO de chacun près de son nom.
    double left(String t) => tester.getRect(find.text(t).last).left;
    double right(String t) => tester.getRect(find.text(t).last).right;
    expect(right('Go'), lessThan(left('Arthur')));
    expect(left('Aumes'), greaterThan(right('Bors')));
    expect(find.text('−4,6'), findsOneWidget);
    expect(find.text('+4,6'), findsOneWidget);
    // ELO du joueur 1 à gauche de son nom, celui du joueur 2 à droite.
    expect(right('−4,6'), lessThan(left('Arthur')));
    expect(left('+4,6'), greaterThan(right('Bors')));
    // La date à gauche du jeu.
    expect(right('21/11/26'), lessThan(left('Go')));

    // Pastilles par jeu dans la liste de ses jeux.
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Victoire'), findsOneWidget);
    expect(find.bySemanticsLabel('Défaite'), findsNWidgets(2));
    semantics.dispose();

    // Ses jeux se trient aussi : par score décroissant au départ, puis par
    // nom avec l'en-tête du détail.
    double top(String t) => tester.getRect(find.text(t)).top;
    expect(top('Échecs'), lessThan(top('Dames')));
    final detailHeader = find.text('Nom').last;
    expect(
      tester.getRect(detailHeader).bottom,
      lessThanOrEqualTo(top('Échecs')),
    );
    await tester.tap(detailHeader);
    await tester.pump();
    expect(top('Dames'), lessThan(top('Échecs')));
    // Le tri de la liste de gauche n'a pas bougé.
    expect(
      tester.getRect(find.text('Lancelot').first).top,
      lessThan(tester.getRect(find.text('Arthur').first).top),
    );
  });

  testWidgets('A party detail has a photo zone', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final detail = (
      date: DateTime(2026, 11, 21),
      matchup: (player1: 'Arthur', score1: 3, score2: 2, player2: 'Bors'),
      game: 'Go',
      place: 'Aumes',
      eloDelta1: 5.0,
      form1: const <Outcome>[],
      form2: const <Outcome>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => RowTable(
            columns: const [
              'Joueur 1',
              'Score 1',
              'Score 2',
              'Joueur 2',
              'Jeu',
            ],
            rows: const [
              ['Arthur', '3', '2', 'Bors', 'Go'],
            ],
            matchups: [detail.matchup],
            matchDetails: [detail],
            photos: const [[]],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Arthur'));
    await tester.pump();

    // Sous la partie : la zone de photos, vide ici, sans titre. Son message
    // est centré dans la place qui reste, en bas de la carte du détail.
    expect(find.text('Photos'), findsNothing);
    final message = tester.getRect(find.text('Aucune photo.'));
    final card = tester.getRect(find.byType(RowList));
    final detailLeft = card.left + RowList.listWidth + RowList.gap;
    expect(message.center.dx, moreOrLessEquals((detailLeft + card.right) / 2));
    final scoreBottom = tester.getRect(find.text('3').last).bottom;
    expect(
      message.center.dy,
      moreOrLessEquals((scoreBottom + 16 + card.bottom) / 2, epsilon: 1),
    );
  });

  testWidgets('Events show their date and sort by name or date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => RowTable(
            columns: const ['Nom', 'Date'],
            rows: const [
              ['Automne', 'Octobre 2026'],
              ['Été', 'Juillet 2027'],
              ['Printemps', '—'],
            ],
            dates: [DateTime(2026, 10, 12), DateTime(2027, 7, 5), null],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(SectionButton).at(1));
    await tester.pumpAndSettle();

    List<String> order() => ['Automne', 'Été', 'Printemps']
      ..sort(
        (a, b) => tester
            .getRect(find.text(a))
            .top
            .compareTo(tester.getRect(find.text(b)).top),
      );

    // La date à droite du nom, sur la même ligne.
    final name = tester.getRect(find.text('Automne'));
    // Mois et année, sans le jour.
    final date = tester.getRect(find.text('Octobre 2026'));
    expect(date.left, greaterThan(name.right));
    expect(date.center.dy, name.center.dy);

    // Par nom au départ (accents ignorés).
    expect(order(), ['Automne', 'Été', 'Printemps']);
    // Par date : la plus récente d'abord, sans date en dernier ; puis
    // l'inverse.
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(order(), ['Été', 'Automne', 'Printemps']);
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(order(), ['Automne', 'Été', 'Printemps']);
  });

  testWidgets('A notch against the top edge shows the four counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(columns: ['Nom'], rows: []),
          loadCounts: () async =>
              (players: 7, events: 1, games: 20, boardGames: 3),
        ),
      ),
    );
    final notch = find.byType(TopNotch);
    // Pendant le chargement : un tiret par nombre.
    expect(
      find.descendant(of: notch, matching: find.text('–')),
      findsNWidgets(4),
    );
    await tester.pump();

    Finder inNotch(String t) =>
        find.descendant(of: notch, matching: find.text(t));
    final values = [inNotch('7'), inNotch('1'), inNotch('20'), inNotch('3')];
    for (final v in values) {
      expect(v, findsOneWidget);
    }
    // Dans l'ordre : joueurs, événements, parties, jeux.
    for (var i = 1; i < values.length; i++) {
      expect(
        tester.getRect(values[i]).left,
        greaterThan(tester.getRect(values[i - 1]).right),
      );
    }
    // Accrochée au bord du haut, centrée, au-dessus de la barre des boutons.
    final box = tester.getRect(
      find.descendant(of: notch, matching: find.byType(Container)).first,
    );
    expect(box.top, lessThan(0));
    expect(box.center.dx, moreOrLessEquals(1400 / 2));
    expect(box.bottom, lessThan(tester.getRect(find.byType(SectionBar)).top));
  });

  testWidgets('Two bookmarks hang from the left edge: Wargame and RPG', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(columns: ['Nom'], rows: []),
          loadCounts: () async =>
              (players: 0, events: 0, games: 0, boardGames: 0),
        ),
      ),
    );
    await tester.pump();

    final bookmarks = find.byType(Bookmark);
    expect(bookmarks, findsNWidgets(2));
    final wargame = tester.getRect(find.text('Wargame'));
    final rpg = tester.getRect(find.text('RPG'));
    // L'un sous l'autre, contre le bord gauche, hors des cartes ; texte
    // vertical ; ensemble centré verticalement sur l'écran.
    expect(rpg.top, greaterThan(wargame.bottom));
    expect(wargame.height, greaterThan(wargame.width));
    expect(wargame.right, lessThan(60));
    expect(
      (wargame.top + rpg.bottom) / 2,
      moreOrLessEquals(800 / 2, epsilon: 25),
    );

    bool active(String label) => tester
        .widget<Bookmark>(
          find.ancestor(of: find.text(label), matching: bookmarks),
        )
        .active;
    expect(active('Wargame'), isTrue);
    expect(active('RPG'), isFalse);
    await tester.tap(find.text('RPG'));
    await tester.pump();
    expect(active('RPG'), isTrue);
    expect(active('Wargame'), isFalse);
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
