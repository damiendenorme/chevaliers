/// Suisse : plusieurs tours, chacun un championnat par groupes (aller
/// simple). Au premier tour, les groupes suivent l'ELO des joueurs au jeu de
/// l'événement ; ensuite, leur ELO à l'événement (tous partent de 1000) :
/// les meilleurs ensemble, puis les suivants, et ainsi de suite.
library;

import 'bracket.dart';
import 'championship.dart';
import 'elo.dart';
import 'rows.dart' show compareNames;

/// Une partie de l'événement : son id, son tour (null : hors tour) et son
/// résultat.
typedef SwissParty = ({int id, int? round, PartyScore score});

/// Les tours formés jusqu'ici (chacun une liste de groupes, chaque groupe
/// ses rencontres), et si tous les tours sont joués.
typedef SwissRounds = ({List<List<List<Fixture>>> rounds, bool complete});

/// Ordre du premier tour de l'événement [event] : [players] par ELO au jeu
/// [game], du meilleur au moins bon (à égalité, par nom). Cet ELO est celui
/// du début de l'événement, figé dès sa première partie : les parties
/// jouées ensuite (de l'événement ou d'ailleurs) ne reforment pas les
/// groupes du premier tour, ce qui ferait perdre leurs rencontres aux
/// résultats déjà saisis. [games] est dans l'ordre chronologique ;
/// [events] donne l'événement de chaque partie (même ordre).
List<BracketPlayer> swissStartOrder(
  List<BracketPlayer> players, {
  required List<EloGame> games,
  required List<int?> events,
  required int event,
  required int? game,
}) {
  final first = events.indexOf(event);
  final elo = computeElo([
    for (final (i, g) in games.indexed)
      if (first < 0 || i < first) g,
  ]);
  double of(int player) => elo[game]?[player] ?? eloStart;
  return [...players]..sort((a, b) {
    final byElo = of(b.$1).compareTo(of(a.$1));
    return byElo != 0 ? byElo : compareNames(a.$2, b.$2);
  });
}

/// [order] découpé en groupes de [size] joueurs, dans l'ordre. Un joueur
/// seul à la fin rejoint le groupe précédent.
List<List<BracketPlayer>> swissGroups(List<BracketPlayer> order, int size) {
  final groups = [
    for (var i = 0; i < order.length; i += size)
      order.sublist(i, i + size > order.length ? order.length : i + size),
  ];
  if (groups.length > 1 && groups.last.length == 1) {
    groups[groups.length - 2] = [...groups[groups.length - 2], groups.last[0]];
    groups.removeLast();
  }
  return groups;
}

/// ELO à l'événement de chaque joueur, d'après [parties] (dans l'ordre
/// chronologique) : tous partent de [eloStart].
Map<int, double> swissElo(Iterable<PartyScore> parties) =>
    computeElo([
      for (final p in parties)
        (
          game: 0,
          player1: p.player1,
          player2: p.player2,
          score1: p.score1,
          score2: p.score2,
        ),
    ])[0] ??
    const {};

/// Tours du suisse entre [players] (dans l'ordre du premier tour), en
/// [roundCount] tours de groupes de [groupSize] joueurs. Un tour n'est
/// formé qu'une fois le précédent entièrement joué ; ses rencontres sont
/// remplies par les [parties] de ce tour (dans l'ordre chronologique).
SwissRounds buildSwiss(
  List<BracketPlayer> players, {
  required int roundCount,
  required int groupSize,
  required List<SwissParty> parties,
}) {
  final deltas = eloDeltas([
    for (final p in parties)
      (
        game: 0,
        player1: p.score.player1,
        player2: p.score.player2,
        score1: p.score.score1,
        score2: p.score.score2,
      ),
  ]);
  final deltaOf = {for (final (i, p) in parties.indexed) p.id: deltas[i]};
  var order = [...players];
  final rounds = <List<List<Fixture>>>[];
  for (var r = 0; r < roundCount; r++) {
    if (r > 0) {
      // Après chaque tour : par ELO à l'événement, d'après les tours déjà
      // joués ; à égalité, l'ordre du tour précédent.
      final elo = swissElo([
        for (final p in parties)
          if (p.round != null && p.round! < r) p.score,
      ]);
      final index = {for (final (i, p) in order.indexed) p.$1: i};
      order = [...order]
        ..sort((a, b) {
          final byElo = (elo[b.$1] ?? eloStart).compareTo(
            elo[a.$1] ?? eloStart,
          );
          return byElo != 0 ? byElo : index[a.$1]!.compareTo(index[b.$1]!);
        });
    }
    final groups = [
      for (final group in swissGroups(order, groupSize))
        buildCalendar(
          group,
          returnLeg: false,
          parties: [
            for (final p in parties)
              if (p.round == r &&
                  group.any((g) => g.$1 == p.score.player1) &&
                  group.any((g) => g.$1 == p.score.player2))
                (id: p.id, score: p.score, delta: deltaOf[p.id]!),
          ],
        ),
    ];
    if (groups.every((g) => g.isEmpty)) break;
    rounds.add(groups);
    final played = groups.every((g) => g.every(isFixturePlayed));
    if (!played) return (rounds: rounds, complete: false);
  }
  return (rounds: rounds, complete: rounds.length == roundCount);
}

/// Classement général : [players] (dans l'ordre du premier tour) par ELO à
/// l'événement, d'après [parties] (dans l'ordre chronologique) ; à égalité,
/// l'ordre du premier tour. Les points d'une ligne sont son ELO arrondi.
List<Standing> swissStandings(
  List<BracketPlayer> players,
  List<PartyScore> parties,
) {
  final elo = swissElo(parties);
  final played = <int, int>{};
  final wins = <int, int>{};
  final draws = <int, int>{};
  final losses = <int, int>{};
  final scored = <int, int>{};
  final conceded = <int, int>{};
  void count(int player, int mine, int theirs) {
    played[player] = (played[player] ?? 0) + 1;
    scored[player] = (scored[player] ?? 0) + mine;
    conceded[player] = (conceded[player] ?? 0) + theirs;
    final outcome = switch (mine.compareTo(theirs)) {
      > 0 => wins,
      < 0 => losses,
      _ => draws,
    };
    outcome[player] = (outcome[player] ?? 0) + 1;
  }

  for (final p in parties) {
    count(p.player1, p.score1, p.score2);
    count(p.player2, p.score2, p.score1);
  }
  final index = {for (final (i, p) in players.indexed) p.$1: i};
  return [
    for (final p in players)
      (
        player: p,
        played: played[p.$1] ?? 0,
        wins: wins[p.$1] ?? 0,
        draws: draws[p.$1] ?? 0,
        losses: losses[p.$1] ?? 0,
        scored: scored[p.$1] ?? 0,
        conceded: conceded[p.$1] ?? 0,
        points: (elo[p.$1] ?? eloStart).round(),
      ),
  ]..sort((a, b) {
    final byElo = b.points.compareTo(a.points);
    return byElo != 0
        ? byElo
        : index[a.player.$1]!.compareTo(index[b.player.$1]!);
  });
}
