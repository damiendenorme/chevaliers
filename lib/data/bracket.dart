/// Tableau d'un événement à élimination : des tours de matchs, du premier
/// tour à la finale. Les joueurs du premier tour sont choisis ; ensuite, le
/// vainqueur de chaque match passe au tour suivant.
library;

/// Un joueur du tableau : (id, nom).
typedef BracketPlayer = (int, String);

/// Un match du tableau : ses deux joueurs (null : case encore vide) et,
/// une fois joué, leurs scores.
typedef BracketMatch = ({
  BracketPlayer? player1,
  BracketPlayer? player2,
  int? score1,
  int? score2,
});

/// Un match enregistré : son tour (0 : premier tour), sa position dans le
/// tour (0 : en haut), ses joueurs (au premier tour seulement) et sa partie
/// une fois joué.
typedef StoredMatch = ({
  int round,
  int position,
  int? player1,
  int? player2,
  int? party,
});

/// Résultat d'une partie : ses joueurs et leurs scores.
typedef PartyScore = ({int player1, int player2, int score1, int score2});

/// Le match a été joué (les deux scores sont connus).
bool isPlayed(BracketMatch m) => m.score1 != null && m.score2 != null;

/// Vainqueur d'un match joué (score le plus haut), ou null.
BracketPlayer? winnerOf(BracketMatch m) {
  final (s1, s2) = (m.score1, m.score2);
  if (s1 == null || s2 == null || s1 == s2) return null;
  return s1 > s2 ? m.player1 : m.player2;
}

/// Tableau de [roundCount] tours (2 : demi-finales et finale ; 6 :
/// trente-deuxièmes de finale à la finale), à partir des matchs
/// enregistrés, des résultats des parties (par id) et des noms des joueurs
/// (par id). Chaque tour a deux fois moins de matchs que le précédent.
List<List<BracketMatch>> buildBracket(
  int roundCount,
  Iterable<StoredMatch> stored,
  Map<int, PartyScore> parties,
  Map<int, String> names,
) {
  final byPlace = {for (final m in stored) (m.round, m.position): m};
  BracketPlayer? player(int? id) => switch (id) {
    final id? when names[id] != null => (id, names[id]!),
    _ => null,
  };

  final rounds = <List<BracketMatch>>[];
  for (var r = 0; r < roundCount; r++) {
    final count = 1 << (roundCount - 1 - r);
    rounds.add([
      for (var p = 0; p < count; p++)
        () {
          final saved = byPlace[(r, p)];
          // Premier tour : les joueurs choisis ; ensuite, les vainqueurs des
          // deux matchs précédents.
          final p1 = r == 0
              ? player(saved?.player1)
              : winnerOf(rounds[r - 1][2 * p]);
          final p2 = r == 0
              ? player(saved?.player2)
              : winnerOf(rounds[r - 1][2 * p + 1]);
          // Scores de sa partie, dans l'ordre des cases.
          final result = parties[saved?.party];
          final (int?, int?) scores = switch (result) {
            final s? when s.player1 == p1?.$1 && s.player2 == p2?.$1 => (
              s.score1,
              s.score2,
            ),
            final s? when s.player1 == p2?.$1 && s.player2 == p1?.$1 => (
              s.score2,
              s.score1,
            ),
            _ => (null, null),
          };
          return (
            player1: p1,
            player2: p2,
            score1: scores.$1,
            score2: scores.$2,
          );
        }(),
    ]);
  }
  return rounds;
}

/// Nom du tour [round] (0 : premier tour) d'un tableau de [roundCount]
/// tours : « Finale », « Demi-finales »…
String bracketRoundName(int roundCount, int round) =>
    switch (roundCount - round) {
      1 => 'Finale',
      2 => 'Demi-finales',
      3 => 'Quarts de finale',
      4 => 'Huitièmes de finale',
      5 => 'Seizièmes de finale',
      _ => 'Trente-deuxièmes de finale',
    };
