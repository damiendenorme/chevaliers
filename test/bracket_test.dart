import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/bracket.dart';
import 'package:chevaliers/data/rows.dart';

void main() {
  const names = {1: 'Arthur', 2: 'Bors', 3: 'Gauvain', 4: 'Lancelot'};

  test('A bracket halves its matches each round, up to the final', () {
    for (final r in EliminationRound.values) {
      final bracket = buildBracket(r.roundCount, const [], const {}, names);
      expect(bracket, hasLength(r.roundCount));
      expect(bracket.last, hasLength(1));
    }
    expect(
      buildBracket(
        EliminationRound.quart.roundCount,
        const [],
        const {},
        names,
      ).first,
      hasLength(4),
    );
    expect(
      buildBracket(
        EliminationRound.trenteDeuxieme.roundCount,
        const [],
        const {},
        names,
      ).first,
      hasLength(32),
    );
  });

  test('Winners move on to the next round', () {
    final bracket = buildBracket(
      2,
      const [
        (round: 0, position: 0, player1: 1, player2: 2, party: 10),
        (round: 0, position: 1, player1: 3, player2: 4, party: 11),
        (round: 1, position: 0, player1: null, player2: null, party: 12),
      ],
      const {
        10: (player1: 1, player2: 2, score1: 3, score2: 1),
        // Enregistrée dans l'autre sens : les scores suivent les cases.
        11: (player1: 4, player2: 3, score1: 5, score2: 2),
        12: (player1: 1, player2: 4, score1: 0, score2: 2),
      },
      names,
    );
    final semi2 = bracket[0][1];
    expect((semi2.score1, semi2.score2), (2, 5));
    expect(winnerOf(semi2), (4, 'Lancelot'));
    final finale = bracket[1][0];
    expect((finale.player1, finale.player2), ((1, 'Arthur'), (4, 'Lancelot')));
    expect(winnerOf(finale), (4, 'Lancelot'));
  });

  test('A match is empty until its players are known', () {
    final bracket = buildBracket(
      2,
      const [(round: 0, position: 0, player1: 1, player2: null, party: null)],
      const {},
      names,
    );
    expect(bracket[0][0].player1, (1, 'Arthur'));
    expect(bracket[0][0].player2, isNull);
    expect(isPlayed(bracket[0][0]), isFalse);
    expect(bracket[1][0].player1, isNull);
  });

  test('Round names, from the first round to the final', () {
    expect(
      [for (var r = 0; r < 3; r++) bracketRoundName(3, r)],
      ['Quarts de finale', 'Demi-finales', 'Finale'],
    );
  });
}
