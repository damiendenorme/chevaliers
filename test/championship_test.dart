import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/championship.dart';

void main() {
  const players = [(1, 'Arthur'), (2, 'Bors'), (3, 'Gauvain'), (4, 'Lancelot')];

  test('Everyone meets everyone once, one match per player per day', () {
    for (final n in [2, 3, 4, 5, 6, 7, 8]) {
      final days = roundRobin([for (var i = 1; i <= n; i++) i]);
      expect(days, hasLength(n.isEven ? n - 1 : n));
      final pairs = <(int, int)>{};
      for (final day in days) {
        final seen = <int>{};
        for (final (a, b) in day) {
          expect(seen.add(a) && seen.add(b), isTrue);
          pairs.add(a < b ? (a, b) : (b, a));
        }
      }
      expect(pairs, hasLength(n * (n - 1) ~/ 2));
    }
  });

  test('A return leg doubles the calendar, sides swapped', () {
    final single = buildCalendar(players, returnLeg: false, parties: const []);
    final double = buildCalendar(players, returnLeg: true, parties: const []);
    expect(single, hasLength(6));
    expect(double, hasLength(12));
    expect(double.last.day, 5);
    expect(
      (double[6].player1, double[6].player2),
      (single[0].player2, single[0].player1),
    );
  });

  test('Parties fill fixtures in order, scores in fixture order', () {
    const parties = [
      (
        id: 10,
        score: (player1: 2, player2: 1, score1: 3, score2: 1),
        delta: 50.0,
      ),
      (
        id: 11,
        score: (player1: 1, player2: 2, score1: 2, score2: 2),
        delta: 0.0,
      ),
    ];
    final calendar = buildCalendar(
      players.sublist(0, 2),
      returnLeg: true,
      parties: parties,
    );
    expect(calendar, hasLength(2));
    // Aller : Arthur contre Bors, rempli par la première partie.
    expect(calendar[0].player1, (1, 'Arthur'));
    expect((calendar[0].score1, calendar[0].score2), (1, 3));
    expect(calendar[0].glory1, -50);
    expect(calendar[1].party, 11);
  });

  test('Standings: points, then score difference, then name', () {
    final fixtures = buildCalendar(
      players.sublist(0, 3),
      returnLeg: false,
      parties: const [
        (
          id: 1,
          score: (player1: 1, player2: 2, score1: 3, score2: 0),
          delta: 50,
        ),
        (
          id: 2,
          score: (player1: 2, player2: 3, score1: 1, score2: 1),
          delta: 0,
        ),
        (
          id: 3,
          score: (player1: 3, player2: 1, score1: 2, score2: 1),
          delta: 40,
        ),
      ],
    );
    final table = standings(players.sublist(0, 3), fixtures, defaultPoints);
    expect([for (final s in table) s.player.$2], ['Gauvain', 'Arthur', 'Bors']);
    expect([for (final s in table) s.points], [4, 3, 1]);
    expect((table[0].wins, table[0].draws, table[0].losses), (1, 1, 0));

    // Gloire en guise de points.
    final glory = standings(players.sublist(0, 3), fixtures, (
      win: 3,
      draw: 1,
      loss: 0,
      glory: true,
    ));
    expect(
      [for (final s in glory) (s.player.$2, s.points)],
      [('Arthur', 10), ('Gauvain', 40), ('Bors', -50)]
        ..sort((a, b) => b.$2.compareTo(a.$2)),
    );
  });

  test('Playoffs: the best meet the last qualified, 1st and 2nd apart', () {
    final table = standings(
      [for (var i = 1; i <= 8; i++) (i, 'J$i')],
      const [],
      defaultPoints,
    );
    // Sans rencontre jouée : l'ordre des noms, J1 à J8.
    final seeded = seedPlayoffs(table, 3)!;
    expect(
      [for (final m in seeded) (m.player1, m.player2)],
      [(1, 8), (4, 5), (2, 7), (3, 6)],
    );
    expect(seedPlayoffs(table.sublist(0, 3), 2), isNull);
  });
}
