import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/auth.dart';
import 'package:chevaliers/data/bracket.dart';
import 'package:chevaliers/data/championship.dart';
import 'package:chevaliers/data/rows.dart';
import 'package:chevaliers/data/swiss.dart';
import 'package:chevaliers/data/rpg_rows.dart';
import 'package:chevaliers/main.dart';
import 'package:chevaliers/widgets/row_list.dart';
import 'package:chevaliers/widgets/rpg_party_dialog.dart';
import 'package:chevaliers/widgets/section_buttons.dart';
import 'package:chevaliers/widgets/top_bar.dart';

/// Connexion factice : un seul compte, arthur@table.fr / excalibur.
class FakeAuth implements AppAuth {
  final _changes = StreamController<bool>.broadcast();
  bool _in = false;

  @override
  Stream<bool> get signedIn async* {
    yield _in;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    if (email != 'arthur@table.fr' || password != 'excalibur') {
      throw const AuthFailure('E-mail ou mot de passe incorrect.');
    }
    _changes.add(_in = true);
  }

  @override
  Future<void> signOut() async => _changes.add(_in = false);
}

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
    // « Discord » : seulement dans sa plaque, en haut à droite.
    expect(
      find.descendant(of: find.byType(Plate), matching: find.text('Discord')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.discord), findsOneWidget);
    Rect plateOf(String label) => tester.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(Plate)),
    );
    final plate = plateOf('Discord');
    final screenRect = tester.getRect(find.byType(MyHomePage));
    expect(plate.top, screenRect.top + 12);
    expect(plate.right, screenRect.right - 12);
    // Instagram dessous, de même largeur ; plus de Facebook.
    final instagram = plateOf('Instagram');
    expect(instagram.top, greaterThan(plate.bottom));
    expect(instagram.width, plate.width);
    expect(instagram.right, plate.right);
    expect(find.text('Facebook'), findsNothing);

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
    // Écran plus large que le tableau (RowList.width).
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
      return ink.decoration == AccentStyle.wargame.texture &&
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
    // Zone de RowList.width, centrée horizontalement.
    final playersTable = tester.getRect(find.byType(RowList));
    expect(playersTable.width, RowList.width);
    expect(playersTable.center.dx, moreOrLessEquals(1400 / 2));
    expect(
      tester.getRect(find.text('Arthur')).left,
      playersTable.left + 5 + 12,
    );

    // Rien de choisi : une invitation au centre de la carte du détail.
    const prompt = 'Sélectionnez un élément à gauche.';
    final promptRect = tester.getRect(find.text(prompt));
    final detailLeft = playersTable.left + RowList.listWidth + RowList.gap;
    expect(
      promptRect.center.dx,
      moreOrLessEquals((detailLeft + playersTable.right) / 2),
    );
    expect(
      promptRect.center.dy,
      moreOrLessEquals(playersTable.center.dy, epsilon: 1),
    );

    // Au clic sur une ligne, son détail s'affiche à droite de la liste.
    await tester.tap(find.text('Lancelot'));
    await tester.pumpAndSettle();
    // En liste : le nom de l'information, puis sa valeur dessous. Le nom du
    // joueur n'est pas repris.
    expect(find.byType(Table), findsNothing);
    expect(find.text('Nom'), findsNothing);
    expect(find.text(prompt), findsNothing);
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
    expect(p1.left, playersTable.left + 5 + 12);
    expect(
      scores.center.dx,
      moreOrLessEquals(playersTable.left + RowList.listWidth / 2),
    );
    expect(p2.right, playersTable.left + RowList.listWidth - 5 - 12);
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
    // Au centre de la carte de gauche.
    final empty = tester.getRect(find.text('Aucune ligne.'));
    final listCard = tester.getRect(find.byType(RowList));
    expect(
      empty.center.dx,
      moreOrLessEquals(listCard.left + RowList.listWidth / 2),
    );
    expect(empty.center.dy, moreOrLessEquals(listCard.center.dy, epsilon: 1));

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
    expect(
      firstValue.right,
      tester.getRect(find.byType(RowList)).right - 5 - 12,
    );
    expect(second.top - first.top, master.height + 9);
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
            .getRect(find.textContaining(a))
            .top
            .compareTo(tester.getRect(find.textContaining(b)).top),
      );
    }

    // Au départ, par score : du meilleur au moins bon, sans score en dernier.
    expect(order(), ['Lancelot', 'Bors', 'Arthur', 'Gauvain']);
    // Trié par score : le rang devant le nom ; pas de rang sans score.
    expect(find.text('1. Lancelot'), findsOneWidget);
    expect(find.text('2. Bors'), findsOneWidget);
    expect(find.text('3. Arthur'), findsOneWidget);
    expect(find.text('Gauvain'), findsOneWidget);
    expect(
      tester.getRect(find.text('Gloire')).bottom,
      lessThanOrEqualTo(tester.getRect(find.textContaining('Lancelot')).top),
    );

    // Clic sur « Gloire » : sens inverse, sans score toujours en dernier.
    await tester.tap(find.text('Gloire'));
    await tester.pump();
    expect(order(), ['Arthur', 'Bors', 'Lancelot', 'Gauvain']);

    // En sens inverse, les rangs restent ceux du classement.
    expect(find.text('3. Arthur'), findsOneWidget);
    expect(find.text('1. Lancelot'), findsOneWidget);

    // Retour au tri par nom, de A à Z, puis de Z à A.
    await tester.tap(find.text('Nom'));
    await tester.pump();
    expect(order(), ['Arthur', 'Bors', 'Gauvain', 'Lancelot']);
    // Trié par nom : plus de rang.
    expect(find.text('Arthur'), findsOneWidget);
    expect(find.text('1. Lancelot'), findsNothing);
    await tester.tap(find.text('Nom'));
    await tester.pump();
    expect(order(), ['Lancelot', 'Gauvain', 'Bors', 'Arthur']);

    // Détail : ses jeux, puis ses parties dessous, au format de la liste.
    await tester.tap(find.textContaining('Arthur'));
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
    expect(find.textContaining('Bors'), findsNWidgets(2));

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
      tester.getRect(find.textContaining('Lancelot').first).top,
      lessThan(tester.getRect(find.textContaining('Arthur').first).top),
    );
  });

  testWidgets('A party detail photo zone: nothing signed out when empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = FakeAuth();
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
            partyIds: const [7],
          ),
          auth: auth,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Arthur'));
    await tester.pump();

    // Déconnecté, sans photo : rien.
    expect(find.text('Aucune photo.'), findsNothing);

    // Connecté : la zone de photos, vide ici, sans titre. Son message est
    // centré dans la place qui reste, en bas de la carte du détail.
    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    expect(find.text('Photos'), findsNothing);
    final message = tester.getRect(find.text('Aucune photo.'));
    final card = tester.getRect(find.byType(RowList));
    final detailLeft = card.left + RowList.listWidth + RowList.gap;
    expect(message.center.dx, moreOrLessEquals((detailLeft + card.right) / 2));
    // Vers le milieu de la place qui reste (avec le bouton « + » dessous).
    final scoreBottom = tester.getRect(find.text('3').last).bottom;
    expect(message.top, greaterThan(scoreBottom));
    expect(message.bottom, lessThan((scoreBottom + card.bottom) / 2 + 20));
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
    // Même hauteur, chacun avec son icône.
    Rect bookmarkOf(String label) => tester.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(Bookmark)),
    );
    expect(bookmarkOf('Wargame').height, Bookmark.height);
    expect(bookmarkOf('RPG').height, Bookmark.height);
    expect(
      find.descendant(of: bookmarks, matching: find.byType(SvgPicture)),
      findsNWidgets(2),
    );
    // L'un sous l'autre, contre le bord gauche ; ensemble centré
    // verticalement sur l'écran.
    final wargameBox = bookmarkOf('Wargame');
    final rpgBox = bookmarkOf('RPG');
    expect(rpgBox.top, greaterThan(wargameBox.bottom));
    expect(
      (wargameBox.top + rpgBox.bottom) / 2,
      moreOrLessEquals(800 / 2, epsilon: 1),
    );
    // Actif : texte horizontal, plus large ; inactif : texte vertical.
    bool horizontal(String label) {
      final r = tester.getRect(find.text(label));
      return r.width > r.height;
    }

    expect(horizontal('Wargame'), isTrue);
    expect(horizontal('RPG'), isFalse);
    expect(wargameBox.width, greaterThan(rpgBox.width));

    bool active(String label) => tester
        .widget<Bookmark>(
          find.ancestor(of: find.text(label), matching: bookmarks),
        )
        .active;
    expect(active('Wargame'), isTrue);
    expect(active('RPG'), isFalse);
    final rpgBefore = bookmarkOf('RPG').width;
    await tester.tap(find.text('RPG'));
    // Animation : à mi-chemin, le marque-page tiré s'élargit encore.
    await tester.pump();
    await tester.pump(Bookmark.duration ~/ 3);
    final rpgDuring = tester.getRect(find.byType(Bookmark).last).width;
    expect(rpgDuring, greaterThan(rpgBefore));
    Color? hoverOf(String label) => tester
        .widget<InkWell>(
          find.descendant(
            of: find.ancestor(of: find.text(label), matching: bookmarks),
            matching: find.byType(InkWell),
          ),
        )
        .hoverColor;
    // Pendant l'animation, le survol est encore là.
    expect(hoverOf('RPG'), isNot(Colors.transparent));
    await tester.pumpAndSettle();
    expect(bookmarkOf('RPG').width, greaterThan(rpgDuring - 1));
    expect(active('RPG'), isTrue);
    // À la fin de l'animation, plus de survol sur le marque-page tiré ;
    // l'autre le retrouve.
    expect(hoverOf('RPG'), Colors.transparent);
    expect(hoverOf('Wargame'), isNot(Colors.transparent));
    expect(active('Wargame'), isFalse);
    expect(horizontal('RPG'), isTrue);
    expect(horizontal('Wargame'), isFalse);
  });

  testWidgets('The RPG bookmark shows its own, independent page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final wargame = <String>[];
    final rpg = <String>[];
    RowTable names(List<String> names) => RowTable(
      columns: const ['Nom'],
      rows: [
        for (final n in names) [n],
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (table) async {
            wargame.add(table);
            return names(['Arthur']);
          },
          loadCounts: () async =>
              (players: 7, events: 1, games: 20, boardGames: 3),
          loadRpgRows: (table) async {
            rpg.add(table);
            return names(['Merlin']);
          },
          loadRpgCounts: () async =>
              (players: 2, events: 0, games: 5, boardGames: 1),
        ),
      ),
    );
    await tester.pump();

    // Wargame au départ, avec ses données et ses nombres.
    expect(find.text('Arthur'), findsOneWidget);
    expect(find.text('Merlin'), findsNothing);
    Finder inNotch(String t) =>
        find.descendant(of: find.byType(TopNotch), matching: find.text(t));
    expect(inNotch('20'), findsOneWidget);

    // Sur Wargame, on passe aux jeux.
    await tester.tap(find.text('Jeux'));
    await tester.pump();
    expect(wargame, ['partie', 'jeu']);

    // Élément choisi (menu, liste) : pas de survol, son fond reste visible.
    // Survol bombé : actif sur les éléments non choisis seulement.
    bool hoverIn(Finder item) => tester
        .widget<HoverBulge>(
          find.ancestor(of: item, matching: find.byType(HoverBulge)).first,
        )
        .enabled;
    expect(hoverIn(find.text('Jeux')), isFalse);
    expect(hoverIn(find.text('Joueurs')), isTrue);
    await tester.pump(); // Chargement de la liste des jeux.
    expect(hoverIn(find.text('Arthur')), isTrue);
    await tester.tap(find.text('Arthur'));
    await tester.pump();
    expect(hoverIn(find.text('Arthur')), isFalse);

    // Au survol d'un élément non choisi : un fond bombé (dégradé vertical).
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Joueurs')));
    await tester.pump();
    final bulge = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find
                .ancestor(
                  of: find.text('Joueurs'),
                  matching: find.byType(HoverBulge),
                )
                .first,
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((bulge.decoration as BoxDecoration).gradient, isA<LinearGradient>());
    await mouse.removePointer();

    // RPG : sa page, avec ses données et ses nombres, au même design.
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    expect(find.text('Merlin'), findsOneWidget);
    expect(find.text('Arthur'), findsNothing);
    expect(inNotch('5'), findsOneWidget);
    expect(inNotch('20'), findsNothing);
    expect(find.byType(SectionBar), findsOneWidget);
    expect(rpg, ['partie']);
    // Accentuation du RPG : le libellé actif (Parties) de sa page.
    final activeInk = tester.widget<Ink>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Parties'),
              matching: find.byType(SectionButton),
            ),
            matching: find.byType(Ink),
          )
          .first,
    );
    expect(activeInk.decoration, AccentStyle.rpg.texture);

    // Retour au Wargame : il a gardé sa section, sans recharger.
    await tester.tap(find.text('Wargame'));
    await tester.pumpAndSettle();
    expect(find.text('Arthur'), findsOneWidget);
    expect(wargame, ['partie', 'jeu']);
  });

  testWidgets('The global score is labelled « Gloire »', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(
            columns: ['Nom'],
            rows: [
              ['Merlin'],
            ],
            forms: [[]],
            globalScores: [1050],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(inList('Gloire'), findsOneWidget);
    expect(inList('Score'), findsNothing);
  });

  testWidgets('Player ids sit in a sortable ID column on the right', (
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
              ['Arthur'],
              ['Bors'],
              ['Gauvain'],
            ],
            forms: [[], [], []],
            globalScores: [1000, 1100, 900],
            ids: [3, 1, 2],
          ),
        ),
      ),
    );
    await tester.pump();

    List<String> order() => ['Arthur', 'Bors', 'Gauvain']
      ..sort(
        (a, b) => tester
            .getRect(find.textContaining(a))
            .top
            .compareTo(tester.getRect(find.textContaining(b)).top),
      );

    // La bannière (id 3) tout à droite de la ligne d'Arthur, sous « ID ».
    final name = tester.getRect(find.textContaining('Arthur'));
    final id = tester.getRect(inList('3'));
    final header = tester.getRect(inList('ID'));
    final listRight =
        tester.getRect(find.byType(RowList)).left + RowList.listWidth;
    expect(id.left, greaterThan(name.right));
    expect(id.center.dy, moreOrLessEquals(name.center.dy, epsilon: 2));
    expect(id.right, lessThanOrEqualTo(listRight - 12));
    // « ID » centré sur les bannières ; la droite de « Gloire » collée à
    // celle des scores.
    final banner = tester.getRect(
      find.ancestor(of: inList('3'), matching: find.byType(ClipPath)).first,
    );
    expect(header.center.dx, moreOrLessEquals(banner.center.dx));
    expect(
      tester.getRect(inList('Gloire')).right,
      moreOrLessEquals(tester.getRect(inList('1000')).right),
    );

    // Tri par ID : croissant, puis décroissant.
    await tester.tap(inList('ID'));
    await tester.pump();
    expect(order(), ['Bors', 'Gauvain', 'Arthur']);
    await tester.tap(inList('ID'));
    await tester.pump();
    expect(order(), ['Arthur', 'Gauvain', 'Bors']);
  });

  testWidgets('« Connexion », bottom left, signs in and out', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(columns: ['Nom'], rows: []),
          auth: FakeAuth(),
        ),
      ),
    );
    await tester.pump();

    // En bas à gauche de l'écran.
    final link = tester.getRect(find.text('Connexion'));
    expect(link.left, lessThan(40));
    expect(link.bottom, greaterThan(800 - 40));

    // Le formulaire : refus, puis connexion.
    await tester.tap(find.text('Connexion'));
    await tester.pumpAndSettle();
    expect(find.text('Se connecter'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'arthur@table.fr');
    await tester.enterText(find.byType(TextField).at(1), 'mauvais');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'excalibur');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Se connecter'), findsNothing);
    expect(find.text('Déconnexion'), findsOneWidget);

    // Déconnexion.
    await tester.tap(find.text('Déconnexion'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion'), findsOneWidget);
  });

  testWidgets('Signed in, a + button adds a player (Wargame or RPG)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final players = ['Arthur'];
    final rpgPlayers = <String>[];
    RowTable table(List<String> names) => RowTable(
      columns: const ['Nom'],
      rows: [
        for (final n in names) [n],
      ],
    );
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => table(players),
          loadRpgRows: (_) async => table(rpgPlayers),
          loadCounts: () async =>
              (players: players.length, events: 0, games: 0, boardGames: 0),
          loadRpgCounts: () async =>
              (players: rpgPlayers.length, events: 0, games: 0, boardGames: 0),
          auth: auth,
          savePlayer: (name) async => players.add(name),
          saveRpgPlayer: (name) async => rpgPlayers.add(name),
        ),
      ),
    );
    await tester.pump();
    final joueurs = find.descendant(
      of: find.byType(SectionBar),
      matching: find.text('Joueurs'),
    );
    await tester.tap(joueurs);
    await tester.pump();

    // Déconnecté : pas de bouton.
    expect(find.byType(AddButton), findsNothing);

    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    expect(find.byType(AddButton), findsOneWidget);

    // Sur les parties du Wargame aussi (ajout de partie).
    await tester.tap(find.text('Parties'));
    await tester.pump();
    expect(find.byType(AddButton), findsOneWidget);
    await tester.tap(joueurs);
    await tester.pump();

    // Ajout : le nom est demandé, enregistré, et la liste rechargée.
    await tester.tap(find.byType(AddButton));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau joueur'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Lancelot');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(players, ['Arthur', 'Lancelot']);
    expect(find.text('Lancelot'), findsOneWidget);

    // Au RPG, dans ses propres données (sa liste est vide au départ).
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    await tester.tap(joueurs);
    await tester.pump();
    await tester.tap(find.byType(AddButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Merlin');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(rpgPlayers, ['Merlin']);
    expect(players, ['Arthur', 'Lancelot']);
    expect(find.text('Merlin'), findsOneWidget);

    // Au RPG aussi, ajout de partie (de JDR).
    await tester.tap(find.text('Parties'));
    await tester.pump();
    expect(find.byType(AddButton), findsOneWidget);
  });

  testWidgets('Signed in, a + button adds an event with an optional date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final events = <(String, DateTime?)>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => RowTable(
            columns: const ['Nom', 'Date'],
            rows: [
              for (final (name, _) in events) [name, '—'],
            ],
            dates: [for (final (_, date) in events) date],
          ),
          loadCounts: () async =>
              (players: 0, events: events.length, games: 0, boardGames: 0),
          auth: auth,
          saveEvent: (name, date) async => events.add((name, date)),
        ),
      ),
    );
    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    await tester.tap(find.text('Événements').first);
    await tester.pump();
    expect(find.byType(AddButton), findsOneWidget);

    await tester.tap(find.byType(AddButton));
    await tester.pumpAndSettle();
    expect(find.text('Nouvel événement'), findsOneWidget);
    // Une date facultative, à choisir.
    expect(find.text('Date : aucune'), findsOneWidget);
    expect(find.text('Choisir'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tournoi de Noël');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(events, [('Tournoi de Noël', null)]);
    expect(find.text('Tournoi de Noël'), findsOneWidget);
  });

  testWidgets('Signed in, a + button adds a game', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final games = <String>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => RowTable(
            columns: const ['Nom'],
            rows: [
              for (final g in games) [g],
            ],
          ),
          loadCounts: () async =>
              (players: 0, events: 0, games: 0, boardGames: games.length),
          auth: auth,
          saveGame: (name) async => games.add(name),
        ),
      ),
    );
    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();

    await tester.tap(find.text('Jeux'));
    await tester.pump();
    await tester.tap(find.byType(AddButton));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau jeu'), findsOneWidget);
    expect(find.text('Choisir'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Mordheim');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(games, ['Mordheim']);
    expect(find.text('Mordheim'), findsOneWidget);
  });

  testWidgets('Signed in, a + button adds a Wargame party', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final parties = <NewParty>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(columns: ['Nom'], rows: []),
          loadCounts: () async =>
              (players: 2, events: 0, games: parties.length, boardGames: 1),
          auth: auth,
          loadPartyOptions: () async => (
            players: [(1, 'Arthur'), (2, 'Lancelot')],
            games: [(5, 'Échecs')],
            places: [(8, 'Aumes'), (9, 'Frontignan')],
          ),
          saveParty: (party) async => parties.add(party),
        ),
      ),
    );
    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();

    // Section de départ : les parties.
    await tester.tap(find.byType(AddButton));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle partie'), findsOneWidget);

    // Sans joueurs : refus.
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(find.text('Choisissez les deux joueurs.'), findsOneWidget);

    Future<void> choose(String label, String item) async {
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int>, label),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    await choose('Joueur 1', 'Arthur');
    await choose('Joueur 2', 'Arthur');
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(find.text('Choisissez deux joueurs différents.'), findsOneWidget);

    await choose('Joueur 2', 'Lancelot');
    await choose('Jeu', 'Échecs');
    final scores = find.widgetWithText(TextField, 'Score');
    await tester.enterText(scores.at(0), '3');
    await tester.enterText(scores.at(1), '2');
    // Lieu : parmi Aumes et Frontignan.
    await choose('Lieu (facultatif)', 'Frontignan');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle partie'), findsNothing);
    expect(parties, hasLength(1));
    final p = parties.single;
    expect(
      (p.player1, p.player2, p.score1, p.score2, p.game, p.place, p.date),
      (1, 2, 3, 2, 5, 9, null),
    );
  });

  testWidgets(
    'Signed in, an empty Wargame event shows « Aucun joueur. », « Aucune partie. »',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = FakeAuth();
      final games = <(int, int)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MyHomePage(
            writeEventGame: (event, game) async => games.add((event, game)),
            loadRows: (_) async => const RowTable(
              columns: ['Nom'],
              rows: [
                ['Camlann'],
              ],
              eventIds: [7],
              eventTypes: [null],
              eventDetails: [(players: [])],
              rowIds: [7],
              eventGames: [null],
              gameOptions: [(5, 'Échecs')],
            ),
            loadCounts: () async =>
                (players: 0, events: 1, games: 0, boardGames: 0),
            auth: auth,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(inList('Camlann'));
      await tester.pump();
      // Déconnecté : rien.
      expect(inList('Aucun joueur.'), findsNothing);
      expect(inList('Aucune partie.'), findsNothing);

      await auth.signIn('arthur@table.fr', 'excalibur');
      await tester.pump();
      // Sans jeu : « Aucun jeu », et pas d'ajout de partie.
      expect(inList('Aucun jeu'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is AddButton && w.label == 'Ajouter une partie',
        ),
        findsNothing,
      );
      expect(inList('Aucun joueur.'), findsOneWidget);
      expect(inList('Aucune partie.'), findsOneWidget);
      expect(
        tester.getRect(inList('Aucun joueur.')).bottom,
        lessThan(tester.getRect(inList('Aucune partie.')).top),
      );

      // Choisir le jeu de l'événement.
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AddButton && w.label == 'Choisir le jeu',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Échecs').last);
      await tester.pumpAndSettle();
      expect(games, [(7, 5)]);
      // Rechargé : on reste sur le détail de l'événement.
      expect(inList('Sélectionnez un élément à gauche.'), findsNothing);
      expect(inList('Aucun jeu'), findsOneWidget);
    },
  );

  testWidgets('Signed in, players then parties are added to a Wargame event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Arthur a joué à l'événement ; Bors y est seulement inscrit.
    final registered = <(int, String)>[(2, 'Bors')];
    final calls = <String>[];
    final parties = <NewParty>[];
    final loaded = <String>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (table) async {
            loaded.add(table);
            return RowTable(
              columns: const ['Nom'],
              rows: const [
                ['Camlann'],
              ],
              rowIds: const [7],
              eventIds: const [7],
              eventTypes: const [null],
              eventPlayed: const [
                {1},
              ],
              eventGames: const [(5, 'Échecs')],
              gameOptions: const [(5, 'Échecs'), (6, 'Go')],
              eventDetails: [
                (
                  players: [
                    (id: 1, name: 'Arthur', glory: 12),
                    for (final (id, name) in registered)
                      (id: id, name: name, glory: 0),
                  ],
                ),
              ],
            );
          },
          loadCounts: () async =>
              (players: 3, events: 1, games: 0, boardGames: 1),
          auth: auth,
          loadPartyOptions: () async => (
            players: [(1, 'Arthur'), (2, 'Bors'), (3, 'Gauvain')],
            games: [(5, 'Échecs')],
            places: [(8, 'Aumes')],
          ),
          saveParty: (party) async => parties.add(party),
          eventPlayers: (
            players: () async => [(1, 'Arthur'), (2, 'Bors'), (3, 'Gauvain')],
            add: (event, player) async {
              calls.add('add $event $player');
              registered.add((player, 'Gauvain'));
            },
            remove: (event, player) async {
              calls.add('remove $event $player');
              registered.removeWhere((p) => p.$1 == player);
            },
            setBracketPlayer: (_, _, _, _) async {},
            playBracketMatch: (_, _, _, _, _) async {},
            saveChampionship: (
              _, {
              returnLeg,
              playoffs,
              points,
              swissRounds,
              groupSize,
            }) async {},
            playFixture: (_, _, _, {round}) async {},
          ),
        ),
      ),
    );
    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    await tester.tap(inList('Camlann'));
    await tester.pump();

    // Une croix pour Bors seulement : Arthur a déjà joué.
    final remove = find.byTooltip("Retirer de l'événement");
    expect(remove, findsOneWidget);

    // Inscrire Gauvain : seuls les non-inscrits sont proposés.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AddButton && w.label == 'Ajouter un joueur',
      ),
    );
    await tester.pumpAndSettle();
    final picker = find.byType(Dialog);
    expect(
      find.descendant(of: picker, matching: find.text('Bors')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: picker, matching: find.text('Gauvain')),
    );
    await tester.pumpAndSettle();
    expect(calls, ['add 7 3']);
    // Rechargé, l'événement reste choisi.
    expect(loaded.last, 'evenement');
    expect(inList('Gauvain'), findsOneWidget);

    // Retirer Bors.
    await tester.tap(remove.first);
    await tester.pumpAndSettle();
    expect(calls, ['add 7 3', 'remove 7 2']);
    expect(inList('Bors'), findsNothing);

    // Une partie de l'événement : entre ses joueurs seulement.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AddButton && w.label == 'Ajouter une partie',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle partie'), findsOneWidget);
    Future<void> choose(String label, String item) async {
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int>, label),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<int>, 'Joueur 1'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bors'), findsNothing);
    await tester.tap(find.text('Arthur').last);
    await tester.pumpAndSettle();
    await choose('Joueur 2', 'Gauvain');
    // Pas de champ Jeu : celui de l'événement.
    expect(
      find.widgetWithText(DropdownButtonFormField<int>, 'Jeu'),
      findsNothing,
    );
    final scores = find.widgetWithText(TextField, 'Score');
    await tester.enterText(scores.at(0), '3');
    await tester.enterText(scores.at(1), '1');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(parties, hasLength(1));
    final p = parties.single;
    expect((p.player1, p.player2, p.game, p.event), (1, 3, 5, 7));
  });

  testWidgets('Signed in, a + button adds an RPG party (GM, guests)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final parties = <NewRpgParty>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRpgRows: (_) async => const RowTable(columns: ['Nom'], rows: []),
          loadRpgCounts: () async =>
              (players: 3, events: 1, games: parties.length, boardGames: 1),
          auth: auth,
          loadRpgPartyOptions: () async => (
            players: [(1, 'Merlin'), (2, 'Morgane'), (3, 'Perceval')],
            games: [(4, 'Pendragon')],
            places: [(8, 'Aumes')],
          ),
          saveRpgParty: (party) async => parties.add(party),
        ),
      ),
    );
    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();

    // Section de départ : les parties ; le bouton ouvre la partie de JDR.
    await tester.tap(find.byType(AddButton));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle partie'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RpgPartyDialog),
        matching: find.text('Joueurs'),
      ),
      findsOneWidget,
    );
    // Date complète, aujourd'hui par défaut.
    expect(
      find.text('Date : ${formatFullDate(DateTime.now())}'),
      findsOneWidget,
    );

    // Sans jeu ni MJ : refus.
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(find.text('Choisissez le jeu.'), findsOneWidget);

    Future<void> choose(String label, String item) async {
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int?>, label),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    await choose('Jeu', 'Pendragon');
    // MJ à cocher : Merlin. Il n'est alors plus proposé parmi les joueurs.
    expect(find.widgetWithText(FilterChip, 'Merlin'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(FilterChip, 'Merlin').first);
    await tester.pump();
    expect(find.widgetWithText(FilterChip, 'Merlin'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Morgane').last);
    await tester.tap(find.widgetWithText(FilterChip, 'Perceval').last);
    await tester.pump();
    // Pas de champ Événement : depuis Parties, sans événement.
    expect(
      find.widgetWithText(
        DropdownButtonFormField<int?>,
        'Événement (facultatif)',
      ),
      findsNothing,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Scénario (facultatif)'),
      'La Tombe de M. Eustache',
    );
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle partie'), findsNothing);
    final p = parties.single;
    expect((p.game, p.place, p.event), (4, null, null));
    expect(p.gms, [1]);
    expect(p.scenario, 'La Tombe de M. Eustache');
    expect(p.guests..sort(), [2, 3]);
    expect(p.date, DateUtils.dateOnly(DateTime.now()));
  });

  testWidgets('Signed in, an RPG event detail adds a party to the event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final parties = <NewRpgParty>[];
    final loaded = <String>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRpgRows: (table) async {
            loaded.add(table);
            return const RowTable(
              columns: ['Nom'],
              rows: [
                ['Paris Éternité'],
              ],
              rowIds: [6],
              eventDetails: [(players: [])],
              sessionLines: [[]],
            );
          },
          loadRpgCounts: () async =>
              (players: 2, events: 1, games: 0, boardGames: 1),
          auth: auth,
          loadRpgPartyOptions: () async => (
            players: [(1, 'Merlin'), (2, 'Morgane')],
            games: [(4, 'Pendragon')],
            places: [(8, 'Aumes')],
          ),
          saveRpgParty: (party) async => parties.add(party),
        ),
      ),
    );
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paris Éternité').last);
    await tester.pumpAndSettle();
    final add = find.byWidgetPredicate(
      (w) => w is AddButton && w.label == 'Ajouter une partie',
    );
    // Déconnecté : ni bouton, ni « Aucune partie. ».
    expect(add, findsNothing);
    expect(find.text('Aucune partie.'), findsNothing);

    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    expect(find.text('Aucune partie.'), findsOneWidget);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle partie'), findsOneWidget);
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int?>, 'Jeu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendragon').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Merlin').first);
    await tester.pump();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    // La partie est de l'événement ; on reste sur son détail.
    expect(parties.single.event, 6);
    expect(loaded.last, 'evenement');
    expect(find.text('Aucune partie.'), findsOneWidget);
  });

  testWidgets('An RPG event detail lists players and their event Glory', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRpgRows: (_) async => RowTable(
            columns: const ['Nom'],
            rows: const [
              ['Paris Éternité'],
            ],
            dates: [DateTime(2027, 12)],
            eventDetails: const [
              (
                players: [
                  (id: 1, name: 'Pokinano', glory: 2),
                  (id: 6, name: 'Andracifus', glory: 5),
                  (id: 2, name: 'Irongab', glory: 1),
                ],
              ),
            ],
            sessionLines: const [
              [
                (
                  label: '28.11.2026 La Crypte des Goules (Paris Éternité 1)',
                  gms: [(1, 'Pokinano')],
                  guests: [(6, 'Andracifus')],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paris Éternité'));
    await tester.pumpAndSettle();

    // Pas de date dans le détail (seulement dans la liste), ni de rôle.
    expect(find.text('Décembre 2027'), findsOneWidget);
    // Sous les joueurs, ses parties, comme dans le détail d'un jeu.
    final party = find.text(
      '28.11.2026 La Crypte des Goules (Paris Éternité 1)',
    );
    expect(party, findsOneWidget);
    expect(
      tester.getRect(party).top,
      greaterThan(tester.getRect(find.text('Pokinano')).bottom),
    );
    expect(find.text('MJ'), findsNothing);
    // À droite de chaque ligne : sa Gloire à l'événement.
    final name = tester.getRect(find.textContaining('Andracifus'));
    final count = tester.getRect(find.text('5'));
    expect(count.left, greaterThan(name.right));
    expect(count.center.dy, moreOrLessEquals(name.center.dy, epsilon: 2));

    List<String> order() => ['Andracifus', 'Irongab', 'Pokinano']
      ..sort(
        (a, b) => tester
            .getRect(find.textContaining(a))
            .top
            .compareTo(tester.getRect(find.textContaining(b)).top),
      );
    final partiesHeader = find.descendant(
      of: find.byType(RowList),
      matching: find.text('Gloire'),
    );
    final nameHeaders = find.descendant(
      of: find.byType(RowList),
      matching: find.text('Nom'),
    );

    // Par nom au départ ; par Gloire (décroissante, puis croissante) ;
    // retour au nom.
    expect(order(), ['Andracifus', 'Irongab', 'Pokinano']);
    // Sans bannière d'id dans la liste des joueurs : celle d'Andracifus (6)
    // n'apparaît plus que dans la liste des parties, dessous. Sans rang tant
    // que la liste est triée par nom.
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Andracifus'), findsOneWidget);
    await tester.tap(partiesHeader);
    await tester.pump();
    expect(order(), ['Andracifus', 'Pokinano', 'Irongab']);
    // Triée par Gloire : le rang devant chaque nom.
    expect(find.text('1. Andracifus'), findsOneWidget);
    expect(find.text('2. Pokinano'), findsOneWidget);
    expect(find.text('3. Irongab'), findsOneWidget);
    await tester.tap(partiesHeader);
    await tester.pump();
    expect(order(), ['Irongab', 'Pokinano', 'Andracifus']);
    await tester.tap(nameHeaders.last);
    await tester.pump();
    expect(order(), ['Andracifus', 'Irongab', 'Pokinano']);
  });

  testWidgets('An RPG party detail: date, scenario, place, then players', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRpgRows: (_) async => RowTable(
            columns: const ['Jeu'],
            rows: const [
              ['Pendragon'],
            ],
            dates: [DateTime(2026, 11, 21)],
            fullDates: true,
            sessionDetails: [
              (
                date: DateTime(2026, 11, 21),
                scenario: 'La Tombe de M. Eustache',
                place: 'Aumes',
                event: 'Paris Éternité',
                gms: [(1, 'Merlin')],
                guests: [(2, 'Morgane'), (3, 'Perceval')],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendragon'));
    await tester.pumpAndSettle();

    double top(String t) => tester.getRect(find.text(t).last).top;
    // Pas le nom du jeu dans le détail (seulement dans la liste).
    expect(find.text('Pendragon'), findsOneWidget);
    // La date, le scénario dessous, l'événement, le lieu en dernier.
    expect(top('La Tombe de M. Eustache'), greaterThan(top('21/11/2026')));
    expect(top('Paris Éternité'), greaterThan(top('La Tombe de M. Eustache')));
    expect(top('Aumes'), greaterThan(top('Paris Éternité')));
    // Puis la liste des joueurs : le MJ d'abord, avec sa bannière.
    expect(top('Merlin'), greaterThan(top('Aumes')));
    expect(top('Morgane'), greaterThan(top('Merlin')));
    expect(top('Perceval'), greaterThan(top('Morgane')));
    expect(find.text('MJ'), findsOneWidget);
    // À droite des autres lignes : « Joueur ».
    expect(find.text('Joueur'), findsNWidgets(2));
    final banner = tester.getRect(find.text('1'));
    final merlin = tester.getRect(find.text('Merlin'));
    expect(banner.right, lessThan(merlin.left));
    expect(banner.center.dy, moreOrLessEquals(merlin.center.dy, epsilon: 2));
  });

  testWidgets('An RPG game detail lists parties with GM and guest banners', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRpgRows: (_) async => const RowTable(
            columns: ['Nom'],
            rows: [
              ['Pendragon'],
            ],
            sessionLines: [
              [
                (
                  label: '21/11/2026',
                  gms: [(1, 'Merlin')],
                  guests: [(2, 'Morgane'), (3, 'Perceval')],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendragon'));
    await tester.pumpAndSettle();

    // La date à gauche ; à droite, le MJ puis les joueurs, sans « MJ : ».
    final date = tester.getRect(find.text('21/11/2026'));
    final gm = tester.getRect(find.text('1'));
    final guest2 = tester.getRect(find.text('2'));
    final guest3 = tester.getRect(find.text('3'));
    expect(find.textContaining('MJ'), findsNothing);
    expect(gm.left, greaterThan(date.right));
    expect(guest2.left, greaterThan(gm.right));
    expect(guest3.left, greaterThan(guest2.right));
    expect(gm.center.dy, moreOrLessEquals(date.center.dy, epsilon: 2));
  });

  testWidgets('A party detail has a summary, editable when signed in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final saved = <(int, String?)>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(
            columns: ['Nom'],
            rows: [
              ['Excalibur'],
            ],
            partyIds: [42],
            summaries: [null],
            photos: [[]],
          ),
          loadCounts: () async =>
              (players: 0, events: 0, games: 1, boardGames: 0),
          auth: auth,
          writeSummary: (id, text) async => saved.add((id, text)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Excalibur'));
    await tester.pump();

    // Bouton rond de modification du résumé.
    final editButton = find.byWidgetPredicate(
      (w) => w is AddButton && w.icon == Icons.edit,
    );
    // Déconnecté, sans résumé : rien (ni message, ni bouton).
    expect(find.text('Aucun résumé.'), findsNothing);
    expect(editButton, findsNothing);

    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    // Connecté : entre les informations et les photos, le résumé, vide,
    // sans titre ; son message centré dans la carte du détail.
    expect(find.text('Résumé'), findsNothing);
    expect(find.text('Aucun résumé.'), findsOneWidget);
    final card = tester.getRect(find.byType(RowList));
    expect(
      tester.getRect(find.text('Aucun résumé.')).center.dx,
      moreOrLessEquals(
        (card.left + RowList.listWidth + RowList.gap + card.right) / 2,
        epsilon: 1,
      ),
    );
    expect(
      tester.getRect(find.text('Aucun résumé.')).bottom,
      lessThan(tester.getRect(find.text('Aucune photo.')).top),
    );
    // Juste sous « Aucun résumé. », centré comme lui.
    final empty = tester.getRect(find.text('Aucun résumé.'));
    final button = tester.getRect(editButton);
    expect(button.top, greaterThan(empty.bottom));
    expect(button.top - empty.bottom, lessThan(16));
    expect(button.center.dx, moreOrLessEquals(empty.center.dx, epsilon: 1));
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Arthur tire l’épée du rocher.',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, [(42, 'Arthur tire l’épée du rocher.')]);
    // Affiché aussitôt, la partie reste sélectionnée.
    expect(find.text('Arthur tire l’épée du rocher.'), findsOneWidget);
    expect(find.text('Aucun résumé.'), findsNothing);
  });

  testWidgets('An elimination event has a number of rounds', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rounds = <(int, EliminationRound)>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(
            columns: ['Nom'],
            rows: [
              ['Camlann'],
              ['Badon'],
            ],
            eventIds: [7, 8],
            eventTypes: [null, EventType.elimination],
            eventRounds: [null, EliminationRound.huitieme],
          ),
          loadCounts: () async =>
              (players: 0, events: 2, games: 0, boardGames: 0),
          auth: auth,
          writeEventType: (_, _) async {},
          writeEventRounds: (id, r) async => rounds.add((id, r)),
        ),
      ),
    );
    await tester.pump();

    // Déconnecté : une élimination montre son premier tour.
    await tester.tap(inList('Badon'));
    await tester.pump();
    expect(inList('Huitièmes de finale'), findsOneWidget);

    // Connecté : sans type, pas de nombre de tours ; avec Élimination, oui.
    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    await tester.tap(inList('Camlann'));
    await tester.pump();
    expect(inList('Aucun nombre de tours'), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AddButton && w.label == 'Choisir le type',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Élimination').last);
    await tester.pumpAndSettle();
    expect(inList('Aucun nombre de tours'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AddButton && w.label == 'Choisir le nombre de tours',
      ),
    );
    await tester.pumpAndSettle();
    for (final r in EliminationRound.values) {
      expect(find.text(r.label), findsOneWidget);
    }
    await tester.tap(find.text('Quarts de finale'));
    await tester.pumpAndSettle();
    expect(rounds, [(7, EliminationRound.quart)]);
    expect(inList('Quarts de finale'), findsOneWidget);
  });

  testWidgets('Signed in, an elimination bracket gets players and scores', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final placed = <(int, int, int, int)>[];
    final played = <(int, int, int, int, PartyScore)>[];
    final auth = FakeAuth();
    // Demi-finales : Arthur contre Bors, à jouer ; la 2e attend ses joueurs.
    final bracket = buildBracket(
      2,
      const [(round: 0, position: 0, player1: 1, player2: 2, party: null)],
      const {},
      const {1: 'Arthur', 2: 'Bors', 3: 'Gauvain'},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => RowTable(
            columns: const ['Nom'],
            rows: const [
              ['Camlann'],
            ],
            rowIds: const [7],
            eventIds: const [7],
            eventTypes: const [EventType.elimination],
            eventRounds: const [EliminationRound.demi],
            eventBrackets: [bracket],
            eventGames: const [(5, 'Échecs')],
            eventDetails: const [
              (
                players: [
                  (id: 1, name: 'Arthur', glory: 0),
                  (id: 2, name: 'Bors', glory: 0),
                  (id: 3, name: 'Gauvain', glory: 0),
                ],
              ),
            ],
          ),
          loadCounts: () async =>
              (players: 3, events: 1, games: 0, boardGames: 1),
          auth: auth,
          eventPlayers: (
            players: () async => const [],
            add: (_, _) async {},
            remove: (_, _) async {},
            setBracketPlayer: (e, pos, side, player) async =>
                placed.add((e, pos, side, player)),
            playBracketMatch: (e, game, round, pos, result) async =>
                played.add((e, game, round, pos, result)),
            saveChampionship: (
              _, {
              returnLeg,
              playoffs,
              points,
              swissRounds,
              groupSize,
            }) async {},
            playFixture: (_, _, _, {round}) async {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(inList('Camlann'));
    await tester.pump();

    // Les tours, et les joueurs placés.
    expect(inList('Demi-finales'), findsWidgets);
    expect(inList('Finale'), findsOneWidget);
    expect(inList('Arthur'), findsWidgets);
    expect(find.text('Choisir…'), findsNothing);

    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    // Une case vide : on y place un inscrit pas encore placé.
    await tester.tap(find.text('Choisir…').first);
    await tester.pumpAndSettle();
    final picker = find.byType(Dialog);
    expect(
      find.descendant(of: picker, matching: find.text('Arthur')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: picker, matching: find.text('Gauvain')),
    );
    await tester.pumpAndSettle();
    expect(placed, [(7, 1, 1, 3)]);

    // Les scores du match prêt : pas d'égalité.
    await tester.tap(find.text('+').first);
    await tester.pumpAndSettle();
    expect(find.text('Scores du match'), findsOneWidget);
    final scores = find.widgetWithText(TextField, 'Score');
    await tester.enterText(scores.at(0), '2');
    await tester.enterText(scores.at(1), '2');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Il faut un vainqueur.'), findsOneWidget);
    await tester.enterText(scores.at(1), '1');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(played, [
      (7, 5, 0, 0, (player1: 1, player2: 2, score1: 2, score2: 1)),
    ]);
  });

  testWidgets('A championship shows its standings, calendar and playoffs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = <(int, bool?, Playoffs?, ChampionshipPoints?)>[];
    final played = <(int, int, PartyScore)>[];
    final auth = FakeAuth();
    const players = [(1, 'Arthur'), (2, 'Bors'), (3, 'Gauvain')];
    // Arthur a battu Bors ; les autres rencontres restent à jouer.
    final fixtures = buildCalendar(
      players,
      returnLeg: false,
      parties: const [
        (
          id: 10,
          score: (player1: 1, player2: 2, score1: 3, score2: 1),
          delta: 50,
        ),
      ],
    );
    final Championship championship = (
      returnLeg: false,
      playoffs: Playoffs.demi,
      points: defaultPoints,
      fixtures: fixtures,
      standings: standings(players, fixtures, defaultPoints),
      playoffBracket: buildBracket(2, const [], const {}, const {}),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => RowTable(
            columns: const ['Nom'],
            rows: const [
              ['Camlann'],
            ],
            rowIds: const [7],
            eventIds: const [7],
            eventTypes: const [EventType.championnat],
            eventChampionships: [championship],
            eventGames: const [(5, 'Échecs')],
            eventDetails: const [
              (
                players: [
                  (id: 1, name: 'Arthur', glory: 50),
                  (id: 2, name: 'Bors', glory: -50),
                  (id: 3, name: 'Gauvain', glory: 0),
                ],
              ),
            ],
          ),
          loadCounts: () async =>
              (players: 3, events: 1, games: 1, boardGames: 1),
          auth: auth,
          eventPlayers: (
            players: () async => const [],
            add: (_, _) async {},
            remove: (_, _) async {},
            setBracketPlayer: (_, _, _, _) async {},
            playBracketMatch: (_, _, _, _, _) async {},
            saveChampionship: (
              e, {
              returnLeg,
              playoffs,
              points,
              swissRounds,
              groupSize,
            }) async => settings.add((e, returnLeg, playoffs, points)),
            playFixture: (e, game, result, {round}) async =>
                played.add((e, game, result)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(inList('Camlann'));
    await tester.pump();

    // Ses réglages, son classement, son calendrier et ses playoffs.
    expect(inList('Aller simple'), findsOneWidget);
    expect(inList('Playoffs : demi-finales'), findsOneWidget);
    expect(inList('Victoire 3 · Nul 1 · Défaite 0'), findsOneWidget);
    expect(inList('Classement'), findsOneWidget);
    expect(inList('1. Arthur'), findsOneWidget);
    expect(inList('Journée 1'), findsOneWidget);
    expect(inList('3 – 1'), findsOneWidget);
    expect(inList('Playoffs'), findsOneWidget);
    expect(inList('Finale'), findsOneWidget);
    expect(find.text('+'), findsNothing);
    // Pas de liste des joueurs à part : le classement les montre.
    expect(inList('Gloire'), findsNothing);

    // Triable : par nom, de Z à A au 2e clic, sans rang ; par nombre, le
    // rang reste celui du classement.
    double top(String t) => tester.getTopLeft(inList(t).first).dy;
    await tester.tap(inList('Nom'));
    await tester.pump();
    await tester.tap(inList('Nom'));
    await tester.pump();
    expect(top('Gauvain') < top('Arthur'), isTrue);
    expect(inList('1. Arthur'), findsNothing);
    await tester.tap(inList('D'));
    await tester.pump();
    expect(top('3. Bors') < top('1. Arthur'), isTrue);

    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();

    // Une rencontre à jouer : le nul est permis.
    await tester.tap(find.text('+').first);
    await tester.pumpAndSettle();
    final scores = find.widgetWithText(TextField, 'Score');
    await tester.enterText(scores.at(0), '2');
    await tester.enterText(scores.at(1), '2');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(played, hasLength(1));
    expect(played.single.$1, 7);
    expect(played.single.$2, 5);
    expect((played.single.$3.score1, played.single.$3.score2), (2, 2));

    // Aller-retour.
    await tester.tap(find.byTooltip('Choisir aller ou aller-retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aller-retour').last);
    await tester.pumpAndSettle();
    expect(settings, [(7, true, null, null)]);

    // Le barème : la Gloire en guise de points.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AddButton && w.label == 'Modifier les points',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(settings.last, (
      7,
      null,
      null,
      (win: 3, draw: 1, loss: 0, glory: true),
    ));
  });

  testWidgets('A Swiss event shows its standings, rounds and settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = <(int?, int?)>[];
    final played = <(int, int?, PartyScore)>[];
    final loaded = <String>[];
    final auth = FakeAuth();
    const players = [
      (1, 'Arthur'),
      (2, 'Bors'),
      (3, 'Gauvain'),
      (4, 'Lancelot'),
    ];
    // Tour 1 joué ; le tour 2 regroupe les vainqueurs, à jouer.
    const parties = [
      (id: 10, round: 0, score: (player1: 1, player2: 2, score1: 3, score2: 0)),
      (id: 11, round: 0, score: (player1: 3, player2: 4, score1: 0, score2: 2)),
    ];
    final built = buildSwiss(
      players,
      roundCount: 3,
      groupSize: 2,
      parties: parties,
    );
    final Swiss swiss = (
      roundCount: 3,
      groupSize: 2,
      playoffs: Playoffs.aucun,
      rounds: built.rounds,
      standings: swissStandings(players, [for (final p in parties) p.score]),
      playoffBracket: null,
      finished: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (t) async => (loaded..add(t)).isEmpty
              ? throw StateError('')
              : RowTable(
                  columns: const ['Nom'],
                  rows: const [
                    ['Camlann'],
                  ],
                  rowIds: const [7],
                  eventIds: const [7],
                  eventTypes: const [EventType.suisse],
                  eventSwiss: [swiss],
                  eventGames: const [(5, 'Échecs')],
                  eventDetails: const [
                    (
                      players: [
                        (id: 1, name: 'Arthur', glory: 0),
                        (id: 2, name: 'Bors', glory: 0),
                        (id: 3, name: 'Gauvain', glory: 0),
                        (id: 4, name: 'Lancelot', glory: 0),
                      ],
                    ),
                  ],
                ),
          loadCounts: () async =>
              (players: 4, events: 1, games: 2, boardGames: 1),
          auth: auth,
          eventPlayers: (
            players: () async => const [],
            add: (_, _) async {},
            remove: (_, _) async {},
            setBracketPlayer: (_, _, _, _) async {},
            playBracketMatch: (_, _, _, _, _) async {},
            saveChampionship: (
              _, {
              returnLeg,
              playoffs,
              points,
              swissRounds,
              groupSize,
            }) async => settings.add((swissRounds, groupSize)),
            playFixture: (e, game, result, {round}) async =>
                played.add((e, round, result)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(inList('Camlann'));
    await tester.pump();

    expect(inList('3 tours'), findsOneWidget);
    expect(inList('Groupes de 2 joueurs'), findsOneWidget);
    expect(inList('Sans playoffs'), findsOneWidget);
    expect(inList('Classement général'), findsOneWidget);
    // Une seule fois : pas de liste des joueurs à part.
    expect(inList('Gloire'), findsOneWidget);
    expect(inList('Tour 1'), findsOneWidget);
    expect(inList('Tour 2'), findsOneWidget);
    expect(inList('Groupe 2'), findsNWidgets(2));
    expect(inList('Tour 3 : formé à la fin du tour 2.'), findsOneWidget);
    expect(inList('3 – 0'), findsOneWidget);

    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();

    // Une rencontre du tour 2 : sa partie est de ce tour.
    await tester.tap(find.text('+').first);
    await tester.pumpAndSettle();
    final scores = find.widgetWithText(TextField, 'Score');
    await tester.enterText(scores.at(0), '1');
    await tester.enterText(scores.at(1), '0');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(played.single.$1, 7);
    expect(played.single.$2, 1);

    // La taille des groupes.
    await tester.tap(find.byTooltip('Choisir la taille des groupes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groupes de 4 joueurs').last);
    await tester.pumpAndSettle();
    expect(settings, [(null, 4)]);

    // Une rencontre jouée mène à sa partie.
    await tester.tap(inList('3 – 0'));
    await tester.pump();
    expect(loaded.last, 'partie');
  });

  testWidgets('A Wargame event has a type, chosen when signed in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final saved = <(int, EventType)>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(
            columns: ['Nom'],
            rows: [
              ['Camlann'],
              ['Badon'],
            ],
            eventIds: [7, 8],
            eventTypes: [null, EventType.suisse],
          ),
          loadCounts: () async =>
              (players: 0, events: 2, games: 0, boardGames: 0),
          auth: auth,
          writeEventType: (id, type) async => saved.add((id, type)),
        ),
      ),
    );
    await tester.pump();
    final chooser = find.byWidgetPredicate(
      (w) => w is AddButton && w.label == 'Choisir le type',
    );

    // Déconnecté : le type en lecture seule ; sans type, rien.
    await tester.tap(inList('Badon'));
    await tester.pump();
    expect(inList('Suisse'), findsOneWidget);
    expect(chooser, findsNothing);
    await tester.tap(inList('Camlann'));
    await tester.pump();
    expect(inList('Aucun type'), findsNothing);

    // Connecté : « Aucun type » et le bouton, qui propose les quatre types.
    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    expect(inList('Aucun type'), findsOneWidget);
    await tester.tap(chooser);
    await tester.pumpAndSettle();
    expect(find.text('Élimination'), findsOneWidget);
    expect(find.text('Suisse'), findsOneWidget);
    expect(find.text('Campagne'), findsOneWidget);
    await tester.tap(find.text('Championnat'));
    await tester.pumpAndSettle();

    expect(saved, [(7, EventType.championnat)]);
    // Affiché aussitôt, l'événement reste sélectionné.
    expect(inList('Championnat'), findsOneWidget);
    expect(inList('Aucun type'), findsNothing);
  });

  testWidgets('Signed in, a + under « Aucune photo. » adds a photo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final uploads = <int>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (_) async => const RowTable(
            columns: ['Nom'],
            rows: [
              ['Excalibur'],
            ],
            partyIds: [42],
            photos: [[]],
          ),
          loadCounts: () async =>
              (players: 0, events: 0, games: 1, boardGames: 0),
          auth: auth,
          uploadPhoto: (id) async {
            uploads.add(id);
            return 'https://example.com/photo.jpg';
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Excalibur'));
    await tester.pump();

    final addPhoto = find.byWidgetPredicate(
      (w) => w is AddButton && w.label == 'Ajouter une photo',
    );
    expect(addPhoto, findsNothing);

    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    // Sous « Aucune photo. », centré.
    final empty = tester.getRect(find.text('Aucune photo.'));
    final button = tester.getRect(addPhoto);
    expect(button.top, greaterThan(empty.bottom));
    expect(button.center.dx, moreOrLessEquals(empty.center.dx, epsilon: 1));

    await tester.tap(addPhoto);
    await tester.pump();
    await tester.pump();
    expect(uploads, [42]);
    // La photo apparaît, la partie reste sélectionnée.
    expect(find.text('Aucune photo.'), findsNothing);
    expect(addPhoto, findsOneWidget);
  });

  testWidgets('Signed in, GMs and players of an RPG party can be edited', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final calls = <String>[];
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRpgRows: (_) async => RowTable(
            columns: const ['Jeu'],
            rows: const [
              ['Pendragon'],
            ],
            dates: [DateTime(2026, 11, 21)],
            fullDates: true,
            partyIds: const [9],
            sessionDetails: [
              (
                date: DateTime(2026, 11, 21),
                scenario: null,
                place: null,
                event: null,
                gms: [(1, 'Merlin')],
                guests: [(2, 'Morgane'), (3, 'Perceval')],
              ),
            ],
          ),
          loadRpgCounts: () async =>
              (players: 4, events: 0, games: 1, boardGames: 1),
          auth: auth,
          rpgGuests: (
            players: () async => [
              (1, 'Merlin'),
              (2, 'Morgane'),
              (3, 'Perceval'),
              (4, 'Gauvain'),
            ],
            add: (party, player, {required gm}) async =>
                calls.add('add $party $player${gm ? ' MJ' : ''}'),
            remove: (party, player) async => calls.add('remove $party $player'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendragon'));
    await tester.pumpAndSettle();

    final remove = find.byTooltip('Retirer de la partie');
    final add = find.byWidgetPredicate(
      (w) => w is AddButton && w.label == 'Ajouter un joueur',
    );
    final addGm = find.byWidgetPredicate(
      (w) => w is AddButton && w.label == 'Ajouter un MJ',
    );
    // Déconnecté : pas de modification.
    expect(remove, findsNothing);
    expect(add, findsNothing);
    expect(addGm, findsNothing);

    await auth.signIn('arthur@table.fr', 'excalibur');
    await tester.pump();
    // Un bouton de retrait par MJ et par joueur.
    expect(remove, findsNWidgets(3));
    expect(addGm, findsOneWidget);

    // Retrait de Morgane (le MJ Merlin est en premier).
    await tester.tap(remove.at(1));
    await tester.pumpAndSettle();
    expect(calls, ['remove 9 2']);
    expect(find.text('Morgane'), findsNothing);
    expect(find.text('Perceval'), findsOneWidget);

    // Ajout : seuls les joueurs absents de la partie sont proposés.
    await tester.tap(add);
    await tester.pumpAndSettle();
    final picker = find.ancestor(
      of: find.text('Ajouter un joueur'),
      matching: find.byType(Dialog),
    );
    Finder inPicker(String t) =>
        find.descendant(of: picker, matching: find.text(t));
    expect(inPicker('Merlin'), findsNothing);
    expect(inPicker('Perceval'), findsNothing);
    expect(inPicker('Morgane'), findsOneWidget);
    await tester.tap(inPicker('Gauvain'));
    await tester.pumpAndSettle();
    expect(calls, ['remove 9 2', 'add 9 4']);
    expect(find.text('Gauvain'), findsOneWidget);

    // Ajout d'un second MJ : Morgane.
    await tester.tap(addGm);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morgane'));
    await tester.pumpAndSettle();
    expect(calls, ['remove 9 2', 'add 9 4', 'add 9 2 MJ']);
    expect(find.text('MJ'), findsNWidgets(2));

    // Retrait du MJ Merlin : une partie peut n'avoir aucun MJ… ou un autre.
    await tester.tap(remove.first);
    await tester.pumpAndSettle();
    expect(calls.last, 'remove 9 1');
    expect(find.text('Merlin'), findsNothing);
    expect(find.text('MJ'), findsOneWidget);
  });

  testWidgets('In a player detail, a game or party leads to it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final party = (
      date: DateTime(2026, 11, 21),
      matchup: (player1: 'Arthur', score1: 7, score2: 9, player2: 'Bors'),
      game: 'Go',
      place: 'Aumes',
      eloDelta1: -4.0,
      form1: const <Outcome>[],
      form2: const <Outcome>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (table) async => switch (table) {
            'joueur' => RowTable(
              columns: const ['Nom'],
              rows: const [
                ['Arthur'],
              ],
              lists: const [
                [('Go', '1050'), ('Échecs', '980')],
              ],
              listIds: const [
                [5, 6],
              ],
              matchLists: [
                [party],
              ],
              matchListIds: const [
                [42],
              ],
            ),
            'jeu' => const RowTable(
              columns: ['Nom'],
              rows: [
                ['Échecs'],
                ['Go'],
              ],
              rowIds: [6, 5],
            ),
            'partie' => RowTable(
              columns: const ['Nom'],
              rows: const [
                ['Autre partie'],
                ['La partie'],
              ],
              rowIds: const [41, 42],
              matchDetails: [party, party],
            ),
            _ => const RowTable(columns: ['Nom'], rows: []),
          },
          loadCounts: () async =>
              (players: 1, events: 0, games: 1, boardGames: 2),
        ),
      ),
    );
    await tester.pump();
    Future<void> openPlayer() async {
      await tester.tap(
        find.descendant(
          of: find.byType(SectionBar),
          matching: find.text('Joueurs'),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Arthur').first);
      await tester.pump();
    }

    // Ligne choisie de la liste de gauche : son texte est en blanc.
    bool selected(String text) =>
        tester.widget<Text>(find.text(text).first).style?.color == Colors.white;

    // Clic sur le jeu « Échecs » : l'onglet Jeux, « Échecs » sélectionné.
    await openPlayer();
    await tester.tap(find.text('Échecs'));
    await tester.pump();
    await tester.pump();
    final jeux = find.descendant(
      of: find.byType(SectionBar),
      matching: find.text('Jeux'),
    );
    expect(
      tester.widget<Text>(jeux).style?.color,
      Colors.white, // libellé actif
    );
    expect(find.text('Sélectionnez un élément à gauche.'), findsNothing);
    expect(selected('Échecs'), isTrue);
    expect(selected('Go'), isFalse);

    // Clic sur sa partie : l'onglet Parties, la partie 42 sélectionnée.
    await openPlayer();
    await tester.tap(find.text('Go').last);
    await tester.pump();
    await tester.pump();
    final parties = find.descendant(
      of: find.byType(SectionBar),
      matching: find.text('Parties'),
    );
    expect(tester.widget<Text>(parties).style?.color, Colors.white);
    expect(find.text('Sélectionnez un élément à gauche.'), findsNothing);
    expect(selected('La partie'), isTrue);
    expect(selected('Autre partie'), isFalse);
  });

  testWidgets('In a game detail, a ranked player or party leads to it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final party = (
      date: DateTime(2026, 11, 21),
      matchup: (player1: 'Arthur', score1: 7, score2: 9, player2: 'Bors'),
      game: 'Go',
      place: 'Aumes',
      eloDelta1: -4.0,
      form1: const <Outcome>[],
      form2: const <Outcome>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRows: (table) async => switch (table) {
            'jeu' => RowTable(
              columns: const ['Nom'],
              rows: const [
                ['Go'],
              ],
              rowIds: const [5],
              listTable: 'joueur',
              lists: const [
                [('1. Bors', '1050'), ('2. Arthur', '950')],
              ],
              listIds: const [
                [2, 1],
              ],
              matchLists: [
                [party],
              ],
              matchListIds: const [
                [42],
              ],
            ),
            'joueur' => const RowTable(
              columns: ['Nom'],
              rows: [
                ['Arthur'],
                ['Bors'],
              ],
              rowIds: [1, 2],
            ),
            'partie' => RowTable(
              columns: const ['Nom'],
              rows: const [
                ['Autre partie'],
                ['La partie'],
              ],
              rowIds: const [41, 42],
              matchDetails: [party, party],
            ),
            _ => const RowTable(columns: ['Nom'], rows: []),
          },
          loadCounts: () async =>
              (players: 2, events: 0, games: 1, boardGames: 1),
        ),
      ),
    );
    await tester.pump();
    Finder tab(String label) => find.descendant(
      of: find.byType(SectionBar),
      matching: find.text(label),
    );
    bool active(String label) =>
        tester.widget<Text>(tab(label)).style?.color == Colors.white;
    bool selected(String text) =>
        tester.widget<Text>(find.text(text).first).style?.color == Colors.white;
    Future<void> openGame() async {
      await tester.tap(tab('Jeux'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Go').first);
      await tester.pump();
    }

    // Clic sur « 1. Bors » : l'onglet Joueurs, Bors sélectionné.
    await openGame();
    await tester.tap(find.text('1. Bors'));
    await tester.pump();
    await tester.pump();
    expect(active('Joueurs'), isTrue);
    expect(selected('Bors'), isTrue);
    expect(selected('Arthur'), isFalse);

    // Clic sur sa partie : l'onglet Parties, la partie 42 sélectionnée.
    await openGame();
    await tester.tap(find.text('Aumes'));
    await tester.pump();
    await tester.pump();
    expect(active('Parties'), isTrue);
    expect(selected('La partie'), isTrue);
  });

  testWidgets('RPG: in a player detail, a party leads to it', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRpgRows: (table) async => switch (table) {
            'joueur' => const RowTable(
              columns: ['Nom'],
              rows: [
                ['Merlin'],
              ],
              sessionLines: [
                [
                  (
                    label: '28.11.2026 La Crypte des Goules',
                    gms: [(1, 'Merlin')],
                    guests: [],
                  ),
                ],
              ],
              sessionLineIds: [
                [7],
              ],
            ),
            'partie' => const RowTable(
              columns: ['Jeu'],
              rows: [
                ['Pendragon'],
                ['Call of Cthulhu'],
              ],
              rowIds: [3, 7],
            ),
            _ => const RowTable(columns: ['Nom'], rows: []),
          },
          loadRpgCounts: () async =>
              (players: 1, events: 0, games: 2, boardGames: 2),
        ),
      ),
    );
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    Finder tab(String label) => find.descendant(
      of: find.byType(SectionBar),
      matching: find.text(label),
    );
    await tester.tap(tab('Joueurs').last);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Merlin'));
    await tester.pump();

    await tester.tap(find.text('28.11.2026 La Crypte des Goules'));
    await tester.pump();
    await tester.pump();
    // La page RPG est la dernière (celle du Wargame reste en mémoire).
    expect(tester.widget<Text>(tab('Parties').last).style?.color, Colors.white);
    expect(
      // Dans la liste (le détail le reprend aussi).
      tester.widget<Text>(find.text('Call of Cthulhu').first).style?.color,
      Colors.white,
    );
    expect(
      tester.widget<Text>(find.text('Pendragon')).style?.color,
      isNot(Colors.white),
    );
  });

  testWidgets('RPG: events, parties and games lead to players and parties', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const line = (
      label: '28.11.2026 La Crypte des Goules',
      gms: [(1, 'Merlin')],
      guests: <(int, String)>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          loadRpgRows: (table) async => switch (table) {
            'evenement' => const RowTable(
              columns: ['Nom'],
              rows: [
                ['Paris Éternité'],
              ],
              eventDetails: [
                (players: [(id: 2, name: 'Morgane', glory: 1)]),
              ],
              sessionLines: [
                [line],
              ],
              sessionLineIds: [
                [7],
              ],
            ),
            'jeu' => const RowTable(
              columns: ['Nom'],
              rows: [
                ['Call of Cthulhu'],
              ],
              sessionLines: [
                [line],
              ],
              sessionLineIds: [
                [7],
              ],
            ),
            'partie' => RowTable(
              columns: const ['Jeu'],
              rows: const [
                ['Pendragon'],
                ['Partie 7'],
              ],
              rowIds: const [3, 7],
              partyIds: const [3, 7],
              sessionDetails: [
                for (final _ in [3, 7])
                  (
                    date: DateTime(2026, 11, 28),
                    scenario: null,
                    place: null,
                    event: null,
                    gms: const [(1, 'Merlin')],
                    guests: const [(2, 'Morgane')],
                  ),
              ],
            ),
            'joueur' => const RowTable(
              columns: ['Nom'],
              rows: [
                ['Merlin'],
                ['Morgane'],
              ],
              rowIds: [1, 2],
            ),
            _ => const RowTable(columns: ['Nom'], rows: []),
          },
          loadRpgCounts: () async =>
              (players: 2, events: 1, games: 1, boardGames: 1),
        ),
      ),
    );
    await tester.tap(find.text('RPG'));
    await tester.pumpAndSettle();
    Finder tab(String label) => find
        .descendant(of: find.byType(SectionBar), matching: find.text(label))
        .last;
    bool active(String label) =>
        tester.widget<Text>(tab(label)).style?.color == Colors.white;
    bool selected(String text) =>
        tester.widget<Text>(find.text(text).first).style?.color == Colors.white;
    Future<void> open(String section, String row) async {
      await tester.tap(tab(section));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text(row).first);
      await tester.pump();
    }

    Future<void> follow(Finder target) async {
      await tester.tap(target);
      await tester.pump();
      await tester.pump();
    }

    // Événement → joueur.
    await open('Événements', 'Paris Éternité');
    await follow(find.text('Morgane'));
    expect(active('Joueurs'), isTrue);
    expect(selected('Morgane'), isTrue);

    // Événement → partie.
    await open('Événements', 'Paris Éternité');
    await follow(find.text('28.11.2026 La Crypte des Goules'));
    expect(active('Parties'), isTrue);
    expect(selected('Partie 7'), isTrue);

    // Partie → joueur (le MJ).
    await follow(find.text('Merlin'));
    expect(active('Joueurs'), isTrue);
    expect(selected('Merlin'), isTrue);

    // Jeu → partie.
    await open('Jeux', 'Call of Cthulhu');
    await follow(find.text('28.11.2026 La Crypte des Goules'));
    expect(active('Parties'), isTrue);
    expect(selected('Partie 7'), isTrue);
  });

  testWidgets('A game ranking sorts by name or score, with ranks', (
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
              ['Go'],
            ],
            sortableLists: true,
            rankedLists: true,
            lists: [
              [('Lancelot', '1100'), ('Bors', '1020'), ('Arthur', '950')],
            ],
          ),
          loadCounts: () async =>
              (players: 3, events: 0, games: 0, boardGames: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(SectionBar), matching: find.text('Jeux')),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pump();

    List<String> order() => ['Arthur', 'Bors', 'Lancelot']
      ..sort(
        (a, b) => tester
            .getRect(find.textContaining(a))
            .top
            .compareTo(tester.getRect(find.textContaining(b)).top),
      );
    Finder header(String t) =>
        find.descendant(of: find.byType(RowList), matching: find.text(t)).last;

    // Par score au départ, avec les rangs.
    expect(order(), ['Lancelot', 'Bors', 'Arthur']);
    expect(find.text('1. Lancelot'), findsOneWidget);
    expect(find.text('3. Arthur'), findsOneWidget);

    // Score inversé : les rangs restent ceux du classement.
    await tester.tap(header('Gloire'));
    await tester.pump();
    expect(order(), ['Arthur', 'Bors', 'Lancelot']);
    expect(find.text('3. Arthur'), findsOneWidget);

    // Par nom : de A à Z, sans rang.
    await tester.tap(header('Nom'));
    await tester.pump();
    expect(order(), ['Arthur', 'Bors', 'Lancelot']);
    expect(find.text('Arthur'), findsOneWidget);
    expect(find.text('1. Lancelot'), findsNothing);
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
