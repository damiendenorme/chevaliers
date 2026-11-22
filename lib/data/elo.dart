import 'dart:math';

/// ELO de départ de tout joueur, pour chaque jeu (Wargame).
const double eloStart = 1000;

/// Départ au RPG : la Gloire commence à 0.
const double rpgEloStart = 0;

/// Facteur K : points au plus gagnés ou perdus en une partie.
const double eloK = 100;

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
/// n'y a jamais joué : son ELO y est [start]. Le meilleur score gagne ;
/// à scores égaux, c'est un match nul.
Map<int, Map<int, double>> computeElo(
  Iterable<EloGame> games, {
  double start = eloStart,
}) => _replay(games, start).elo;

/// Évolution du ELO du joueur 1 à chaque partie de [games] (dans le même
/// ordre, chronologique) ; celle du joueur 2 est l'opposée.
List<double> eloDeltas(Iterable<EloGame> games, {double start = eloStart}) =>
    _replay(games, start).deltas;

/// Rejoue les parties dans l'ordre : ELO final et évolution à chaque partie.
({Map<int, Map<int, double>> elo, List<double> deltas}) _replay(
  Iterable<EloGame> games,
  double start,
) {
  final elo = <int, Map<int, double>>{};
  final deltas = <double>[];
  for (final g in games) {
    final ratings = elo.putIfAbsent(g.game, () => {});
    final r1 = ratings[g.player1] ?? start;
    final r2 = ratings[g.player2] ?? start;
    final expected1 = 1 / (1 + pow(10, (r2 - r1) / 400));
    final actual1 = g.score1 > g.score2
        ? 1.0
        : g.score1 < g.score2
        ? 0.0
        : 0.5;
    final delta = eloK * (actual1 - expected1);
    ratings[g.player1] = r1 + delta;
    ratings[g.player2] = r2 - delta;
    deltas.add(delta);
  }
  return (elo: elo, deltas: deltas);
}

/// ELO de [player] au jeu [game], tel qu'affiché (arrondi à l'unité).
int eloOf(Map<int, Map<int, double>> elo, int game, int player) =>
    (elo[game]?[player] ?? eloStart).round();
