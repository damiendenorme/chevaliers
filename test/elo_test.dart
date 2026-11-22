import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/elo.dart';
import 'package:chevaliers/data/rows.dart';
import 'package:chevaliers/data/rpg_rows.dart';

EloGame g(int game, int p1, int p2, int s1, int s2) =>
    (game: game, player1: p1, player2: p2, score1: s1, score2: s2);

void main() {
  group('computeElo', () {
    test('everyone starts at 1000', () {
      final elo = computeElo([]);
      expect(eloOf(elo, 1, 1), 1000);
    });

    test('a win between equals moves K/2 = 50 points', () {
      final elo = computeElo([g(1, 1, 2, 3, 1)]);
      expect(elo[1]![1], 1050);
      expect(elo[1]![2], 950);
    });

    test('a draw between equals changes nothing', () {
      final elo = computeElo([g(1, 1, 2, 2, 2)]);
      expect(elo[1]![1], 1000);
      expect(elo[1]![2], 1000);
    });

    test('beating a stronger player earns more', () {
      final elo = computeElo([
        g(1, 1, 2, 1, 0), // 1 : 1050, 2 : 950
        g(1, 3, 1, 1, 0), // 3 (1000) bat 1 (1050)
      ]);
      final gain = elo[1]![3]! - 1000;
      expect(gain, greaterThan(50));
      expect(gain, lessThan(100));
      expect(elo[1]![1]! + elo[1]![2]! + elo[1]![3]!, closeTo(3000, 1e-9));
    });

    test('each game has its own ranking', () {
      final elo = computeElo([g(1, 1, 2, 1, 0), g(2, 2, 1, 1, 0)]);
      expect(eloOf(elo, 1, 1), 1050);
      expect(eloOf(elo, 2, 1), 950);
      expect(eloOf(elo, 3, 1), 1000);
    });
  });

  test('ranking lists only players who played, best first, ties by name', () {
    expect(
      ranking({1: 104.6, 2: 95}, {1: 'Arthur', 2: 'Lancelot', 3: 'Bors'}),
      [('1. Arthur', '105'), ('2. Lancelot', '95')],
    );
    expect(ranking({2: 100, 1: 100}, {2: 'Lancelot', 1: 'Arthur', 3: 'Bors'}), [
      ('1. Arthur', '100'),
      ('2. Lancelot', '100'),
    ]);
    expect(ranking({}, {1: 'Arthur'}), isEmpty);
  });

  test('playerGames lists only games played, best ELO first, ties by name', () {
    final elo = {
      1: {7: 98.0, 8: 102.0},
      2: {7: 104.4},
      3: {8: 100.0},
      4: {7: 98.0},
    };
    final games = {1: 'Go', 2: 'Échecs', 3: 'Dames', 4: 'Awalé'};
    expect(playerGames(elo, 7, games), [
      ('Échecs', '104'),
      ('Awalé', '98'),
      ('Go', '98'),
    ]);
    expect(playerGames(elo, 9, games), isEmpty);
  });

  test('recentForm gives the last 5 results, oldest first, all games', () {
    final games = [
      g(1, 7, 2, 1, 0), // victoire (joueur 1)
      g(2, 3, 7, 1, 0), // défaite (joueur 2)
      g(1, 7, 3, 2, 2), // nul
      g(2, 4, 5, 1, 0), // sans 7
      g(1, 2, 7, 0, 3), // victoire (joueur 2)
      g(2, 7, 4, 0, 1), // défaite (joueur 1)
      g(1, 5, 7, 4, 4), // nul
    ];
    expect(recentForm(games, 7), [
      Outcome.loss,
      Outcome.draw,
      Outcome.win,
      Outcome.loss,
      Outcome.draw,
    ]);
    expect(recentForm(games, 4), [Outcome.win, Outcome.win]);
    expect(recentForm(games, 9), isEmpty);
  });

  test('globalElo averages the ELO of the games played', () {
    final elo = {
      1: {7: 110.0, 8: 90.0},
      2: {7: 95.0},
      3: {8: 100.0},
    };
    expect(globalElo(elo, 7), 103); // (110 + 95) / 2 = 102,5
    expect(globalElo(elo, 8), 95);
    expect(globalElo(elo, 9), isNull);
  });

  test('eloDeltas gives the change of player 1 at each game', () {
    final games = [g(1, 1, 2, 3, 1), g(1, 2, 1, 0, 0), g(2, 1, 2, 0, 5)];
    final deltas = eloDeltas(games);
    expect(deltas, hasLength(3));
    expect(deltas[0], 50); // victoire entre égaux
    // Nul : le moins bien classé (2, à 950) gagne un peu.
    expect(deltas[1], greaterThan(0));
    expect(deltas[2], -50); // autre jeu : défaite entre égaux
  });

  test('compareNames ignores accents and case', () {
    final names = ['Go', 'échecs', 'Dames', 'Échecs', 'awalé'];
    expect(names..sort(compareNames), [
      'awalé',
      'Dames',
      'Échecs',
      'échecs',
      'Go',
    ]);
  });

  test('formatMonth shows the month and year only', () {
    expect(formatMonth(DateTime(2027, 12)), 'Décembre 2027');
    expect(formatMonth(DateTime(2026, 8, 15)), 'Août 2026');
  });

  test('resolveImageAsset finds a .jpg, .jpeg or .png banner', () {
    const assets = [
      'assets/bannieres/jeu/1.jpg',
      'assets/bannieres/jeu/2.JPEG',
      'assets/bannieres/jeu/3.png',
      'assets/bannieres/jeu/4.png',
      'assets/bannieres/jeu/4.jpg',
      'assets/bannieres/jeu/5.gif',
    ];
    String? find(int id) => resolveImageAsset(bannerAsset('jeu', id), assets);
    expect(find(1), 'assets/bannieres/jeu/1.jpg');
    expect(find(2), 'assets/bannieres/jeu/2.JPEG');
    expect(find(3), 'assets/bannieres/jeu/3.png');
    expect(find(4), 'assets/bannieres/jeu/4.jpg'); // .jpg avant .png
    expect(find(5), isNull);
    expect(find(6), isNull);
    // 10 ne doit pas trouver 1.
    expect(resolveImageAsset(bannerAsset('jeu', 10), assets), isNull);
  });

  test('RPG: the Gloire starts at 0', () {
    final elo = computeElo([g(1, 1, 2, 3, 1)], start: rpgEloStart);
    expect(elo[1]![1], 50);
    expect(elo[1]![2], -50);
    expect(globalElo(computeElo([], start: rpgEloStart), 1), isNull);
  });

  test('rpgSessionTitle: date, scenario, event and its order number', () {
    expect(
      rpgSessionTitle(
        DateTime(2026, 11, 28),
        scenario: 'La Tombe de M. Eustache',
        event: ('Paris Éternité', 1),
      ),
      '28.11.2026 La Tombe de M. Eustache (Paris Éternité 1)',
    );
    expect(rpgSessionTitle(DateTime(2026, 3, 5)), '05.03.2026');
    expect(
      rpgSessionTitle(DateTime(2026, 3, 5), event: ('Trench Crusade', 2)),
      '05.03.2026 (Trench Crusade 2)',
    );
  });

  test('rpgGlory: 1 per party, +2 first of an event, +5 first of a game', () {
    GlorySession party(int id, int day, int game, int? event, Set<int> who) => (
      id: id,
      date: DateTime(2026, 11, day),
      game: game,
      event: event,
      people: who,
    );
    final glory = rpgGlory([
      // Ordre de saisie mélangé : le calcul suit les dates.
      party(3, 20, 1, 7, {1, 3}), // 2e partie du jeu 1, 2e de l'événement 7
      party(1, 10, 1, 7, {
        1,
        2,
      }), // 1re du jeu 1 (+5), 1re de l'événement 7 (+2)
      party(2, 15, 2, null, {2}), // 1re du jeu 2 (+5), sans événement
      party(4, 15, 2, null, {3}), // même jour, id plus grand : pas la 1re
    ]);
    expect(glory[1], 8 + 1); // 1+5+2, puis 1
    expect(glory[2], 8 + 6); // 1+5+2, puis 1+5
    expect(glory[3], 1 + 1); // 1, puis 1
    expect(glory[4], isNull); // aucune partie
  });
}
