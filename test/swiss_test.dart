import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/championship.dart';
import 'package:chevaliers/data/swiss.dart';

void main() {
  const players = [(1, 'Arthur'), (2, 'Bors'), (3, 'Gauvain'), (4, 'Lancelot')];

  SwissParty party(int id, int round, int p1, int p2, int s1, int s2) => (
    id: id,
    round: round,
    score: (player1: p1, player2: p2, score1: s1, score2: s2),
  );

  test('Groups of x, a lone player joins the previous group', () {
    final five = [...players, (5, 'Perceval')];
    expect([for (final g in swissGroups(five, 2)) g.length], [2, 3]);
    expect([for (final g in swissGroups(five, 3)) g.length], [3, 2]);
  });

  test('The first round follows the given order', () {
    final built = buildSwiss(
      players,
      roundCount: 2,
      groupSize: 2,
      parties: const [],
    );
    expect(built.rounds, hasLength(1));
    expect(built.complete, isFalse);
    final groups = built.rounds.single;
    expect(groups, hasLength(2));
    expect((groups[0].single.player1.$1, groups[0].single.player2.$1), (1, 2));
    expect((groups[1].single.player1.$1, groups[1].single.player2.$1), (3, 4));
  });

  test('Once a round is played, the best are grouped together', () {
    // Tour 1 : Arthur bat Bors, Lancelot bat Gauvain.
    final parties = [party(10, 0, 1, 2, 3, 0), party(11, 0, 3, 4, 0, 2)];
    final built = buildSwiss(
      players,
      roundCount: 2,
      groupSize: 2,
      parties: parties,
    );
    expect(built.rounds, hasLength(2));
    final second = built.rounds[1];
    // Les deux vainqueurs ensemble, puis les deux perdants.
    expect({second[0].single.player1.$1, second[0].single.player2.$1}, {1, 4});
    expect({second[1].single.player1.$1, second[1].single.player2.$1}, {2, 3});
    expect(second.expand((g) => g).any(isFixturePlayed), isFalse);

    // Le tour 2 joué : tout est fini.
    final done = buildSwiss(
      players,
      roundCount: 2,
      groupSize: 2,
      parties: [...parties, party(12, 1, 1, 4, 1, 1), party(13, 1, 2, 3, 2, 1)],
    );
    expect(done.complete, isTrue);
    expect(done.rounds[1].expand((g) => g).every(isFixturePlayed), isTrue);
  });

  test('The first round order is frozen once the event has started', () {
    // Avant l'événement 7 : Lancelot bat Arthur au jeu 5.
    const before = (game: 5, player1: 4, player2: 1, score1: 2, score2: 0);
    // Pendant : Arthur écrase Lancelot, à l'événement puis ailleurs.
    const during = (game: 5, player1: 1, player2: 4, score1: 9, score2: 0);
    final order = swissStartOrder(
      players,
      games: const [before, during, during],
      events: const [null, 7, null],
      event: 7,
      game: 5,
    );
    expect(order.first.$1, 4);
    expect(order.last.$1, 1);
    // Sans partie de l'événement : l'ELO actuel.
    final now = swissStartOrder(
      players,
      games: const [before, during, during],
      events: const [null, null, null],
      event: 7,
      game: 5,
    );
    expect(now.first.$1, 1);
  });

  test('The general standings follow the ELO at the event', () {
    final table = swissStandings(players, [
      (player1: 4, player2: 3, score1: 2, score2: 0),
      (player1: 1, player2: 2, score1: 1, score2: 1),
    ]);
    expect(table.first.player.$1, 4);
    expect(table.first.points, greaterThan(1000));
    expect(table.last.player.$1, 3);
    // À ELO égal, l'ordre du premier tour : Arthur avant Bors.
    expect([for (final s in table) s.player.$1], [4, 1, 2, 3]);
    expect((table[1].played, table[1].draws), (1, 1));
  });
}
