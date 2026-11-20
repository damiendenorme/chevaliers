import 'dart:math';

/// ELO de départ de tout joueur, pour chaque jeu.
const double eloStart = 100;

/// Facteur K : points au plus gagnés ou perdus en une partie.
const double eloK = 10;

/// Une partie jouée, pour le calcul du ELO.
typedef EloGame = ({
  int game,
  int player1,
  int player2,
  int score1,
  int score2,
});

/// ELO de chaque joueur pour chaque jeu, à partir des parties [games] données
/// dans l'ordre chronologique : `elo[jeu][joueur]`.
///
/// Chaque jeu a son propre classement. Un joueur absent de la carte d'un jeu
/// n'y a jamais joué : son ELO y est [eloStart]. Le meilleur score gagne ;
/// à scores égaux, c'est un match nul.
Map<int, Map<int, double>> computeElo(Iterable<EloGame> games) {
  final elo = <int, Map<int, double>>{};
  for (final g in games) {
    final ratings = elo.putIfAbsent(g.game, () => {});
    final r1 = ratings[g.player1] ?? eloStart;
    final r2 = ratings[g.player2] ?? eloStart;
    final expected1 = 1 / (1 + pow(10, (r2 - r1) / 400));
    final actual1 = g.score1 > g.score2
        ? 1.0
        : g.score1 < g.score2
        ? 0.0
        : 0.5;
    final delta = eloK * (actual1 - expected1);
    ratings[g.player1] = r1 + delta;
    ratings[g.player2] = r2 - delta;
  }
  return elo;
}

/// ELO de [player] au jeu [game], tel qu'affiché (arrondi à l'unité).
int eloOf(Map<int, Map<int, double>> elo, int game, int player) =>
    (elo[game]?[player] ?? eloStart).round();
