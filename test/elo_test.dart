import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/elo.dart';
import 'package:chevaliers/data/rows.dart';

EloGame g(int game, int p1, int p2, int s1, int s2) =>
    (game: game, player1: p1, player2: p2, score1: s1, score2: s2);

void main() {
  group('computeElo', () {
    test('everyone starts at 100', () {
      final elo = computeElo([]);
      expect(eloOf(elo, 1, 1), 100);
    });

    test('a win between equals moves K/2 = 5 points', () {
      final elo = computeElo([g(1, 1, 2, 3, 1)]);
      expect(elo[1]![1], 105);
      expect(elo[1]![2], 95);
    });

    test('a draw between equals changes nothing', () {
      final elo = computeElo([g(1, 1, 2, 2, 2)]);
      expect(elo[1]![1], 100);
      expect(elo[1]![2], 100);
    });

    test('beating a stronger player earns more', () {
      final elo = computeElo([
        g(1, 1, 2, 1, 0), // 1 : 105, 2 : 95
        g(1, 3, 1, 1, 0), // 3 (100) bat 1 (105)
      ]);
      final gain = elo[1]![3]! - 100;
      expect(gain, greaterThan(5));
      expect(gain, lessThan(10));
      expect(elo[1]![1]! + elo[1]![2]! + elo[1]![3]!, closeTo(300, 1e-9));
    });

    test('each game has its own ranking', () {
      final elo = computeElo([g(1, 1, 2, 1, 0), g(2, 2, 1, 1, 0)]);
      expect(eloOf(elo, 1, 1), 105);
      expect(eloOf(elo, 2, 1), 95);
      expect(eloOf(elo, 3, 1), 100);
    });
  });

  test('ranking lists every player, best first, ties by name', () {
    expect(
      ranking({1: 104.6, 2: 95}, {1: 'Arthur', 2: 'Lancelot', 3: 'Bors'}),
      [('1. Arthur', '105'), ('2. Bors', '100'), ('3. Lancelot', '95')],
    );
    expect(ranking({}, {2: 'Lancelot', 1: 'Arthur'}), [
      ('1. Arthur', '100'),
      ('2. Lancelot', '100'),
    ]);
  });
}
