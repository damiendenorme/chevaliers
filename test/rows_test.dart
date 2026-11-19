import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/data/rows.dart';

void main() {
  group('favoriteGame', () {
    const games = [
      (1, 2, 'Échecs'),
      (3, 1, 'Go'),
      (1, 3, 'Go'),
      (2, 3, 'Dames'),
      (2, 3, 'Dames'),
    ];

    test('counts games played as player 1 or player 2', () {
      expect(favoriteGame(1, games), 'Go');
      expect(favoriteGame(3, games), 'Dames');
    });

    test('breaks ties alphabetically', () {
      // Joueur 2 : Dames ×2, Échecs ×1 → Dames.
      expect(favoriteGame(2, games), 'Dames');
      expect(favoriteGame(4, const [(4, 5, 'Go'), (5, 4, 'Dames')]), 'Dames');
    });

    test('is null for a player without games', () {
      expect(favoriteGame(9, games), isNull);
    });
  });
}
