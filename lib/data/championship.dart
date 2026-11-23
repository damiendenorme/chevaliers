/// Championnat : chaque joueur rencontre tous les autres, une fois (aller
/// simple) ou deux fois (aller-retour), journée après journée. Le classement
/// compte les points de chaque rencontre jouée ; les premiers peuvent
/// ensuite se qualifier pour des playoffs, joués comme une élimination.
library;

import 'bracket.dart';
import 'rows.dart' show compareNames;

/// Une rencontre du calendrier : sa journée (0 : la première), ses joueurs
/// et, une fois jouée, sa partie, les scores et la Gloire gagnée par le
/// joueur 1 (celle du joueur 2 est l'opposée).
typedef Fixture = ({
  int day,
  BracketPlayer player1,
  BracketPlayer player2,
  int? party,
  int? score1,
  int? score2,
  double? glory1,
});

/// Une partie de l'événement : son id, son résultat et la variation de ELO
/// de son joueur 1.
typedef EventParty = ({int id, PartyScore score, double delta});

/// Barème d'un championnat : points à la victoire, au nul et à la défaite,
/// ou bien ([glory]) la Gloire gagnée en guise de points.
typedef ChampionshipPoints = ({int win, int draw, int loss, bool glory});

/// Barème par défaut : 3 points la victoire, 1 le nul, 0 la défaite.
const ChampionshipPoints defaultPoints = (
  win: 3,
  draw: 1,
  loss: 0,
  glory: false,
);

/// Une ligne du classement : le joueur, ses rencontres jouées, gagnées,
/// nulles et perdues, ses scores marqués et encaissés, et ses points.
typedef Standing = ({
  BracketPlayer player,
  int played,
  int wins,
  int draws,
  int losses,
  int scored,
  int conceded,
  int points,
});

/// La rencontre a été jouée.
bool isFixturePlayed(Fixture f) => f.score1 != null && f.score2 != null;

/// Journées d'un tournoi où chacun de [players] rencontre une fois chacun
/// des autres (méthode du cercle) : chaque journée est une liste de
/// rencontres (joueur 1, joueur 2). Avec un nombre impair de joueurs, un
/// joueur est exempt à chaque journée.
List<List<(int, int)>> roundRobin(List<int> players) {
  final slots = <int?>[...players, if (players.length.isOdd) null];
  final n = slots.length;
  final days = <List<(int, int)>>[];
  for (var d = 0; d < n - 1; d++) {
    days.add([
      for (var i = 0; i < n ~/ 2; i++)
        if ((slots[i], slots[n - 1 - i]) case (final a?, final b?))
          // Le premier joueur, fixe, change de côté d'une journée à l'autre.
          i == 0 && d.isOdd ? (b, a) : (a, b),
    ]);
    // Tous tournent d'un cran, sauf le premier.
    slots.insert(1, slots.removeLast());
  }
  return [
    for (final day in days)
      if (day.isNotEmpty) day,
  ];
}

/// Calendrier du championnat entre [players] : les journées de l'aller,
/// puis, avec [returnLeg], celles du retour (côtés inversés). Les [parties]
/// de l'événement (dans l'ordre chronologique) remplissent les rencontres
/// de leurs deux joueurs, dans l'ordre : la première l'aller, la deuxième
/// le retour.
List<Fixture> buildCalendar(
  List<BracketPlayer> players, {
  required bool returnLeg,
  required Iterable<EventParty> parties,
}) {
  (int, int) pair(int a, int b) => a < b ? (a, b) : (b, a);
  final byId = {for (final p in players) p.$1: p};
  final days = roundRobin([...byId.keys]..sort());
  final all = [
    ...days,
    if (returnLeg)
      for (final day in days) [for (final (a, b) in day) (b, a)],
  ];
  final byPair = <(int, int), List<EventParty>>{};
  for (final p in parties) {
    byPair.putIfAbsent(pair(p.score.player1, p.score.player2), () => []).add(p);
  }
  final used = <(int, int), int>{};
  return [
    for (final (d, day) in all.indexed)
      for (final (a, b) in day)
        () {
          final key = pair(a, b);
          final n = used[key] = (used[key] ?? 0) + 1;
          final party = byPair[key]?.elementAtOrNull(n - 1);
          // Scores et Gloire dans l'ordre des joueurs de la rencontre.
          final (int?, int?, double?) result = switch (party) {
            null => (null, null, null),
            final p when p.score.player1 == a => (
              p.score.score1,
              p.score.score2,
              p.delta,
            ),
            final p => (p.score.score2, p.score.score1, -p.delta),
          };
          return (
            day: d,
            player1: byId[a]!,
            player2: byId[b]!,
            party: party?.id,
            score1: result.$1,
            score2: result.$2,
            glory1: result.$3,
          );
        }(),
  ];
}

/// Classement des [players] d'après les rencontres jouées de [fixtures],
/// selon le barème [points] : du plus de points au moins ; à égalité, la
/// meilleure différence de scores, puis par nom.
List<Standing> standings(
  List<BracketPlayer> players,
  List<Fixture> fixtures,
  ChampionshipPoints points,
) {
  final played = <int, int>{};
  final wins = <int, int>{};
  final draws = <int, int>{};
  final losses = <int, int>{};
  final scored = <int, int>{};
  final conceded = <int, int>{};
  final total = <int, double>{};
  void count(int player, int mine, int theirs, double glory) {
    played[player] = (played[player] ?? 0) + 1;
    scored[player] = (scored[player] ?? 0) + mine;
    conceded[player] = (conceded[player] ?? 0) + theirs;
    final (outcome, gained) = switch (mine.compareTo(theirs)) {
      > 0 => (wins, points.win),
      < 0 => (losses, points.loss),
      _ => (draws, points.draw),
    };
    outcome[player] = (outcome[player] ?? 0) + 1;
    total[player] =
        (total[player] ?? 0) + (points.glory ? glory : gained.toDouble());
  }

  for (final f in fixtures) {
    if ((f.score1, f.score2) case (final s1?, final s2?)) {
      final glory = f.glory1 ?? 0;
      count(f.player1.$1, s1, s2, glory);
      count(f.player2.$1, s2, s1, -glory);
    }
  }
  final table = [
    for (final p in players)
      (
        player: p,
        played: played[p.$1] ?? 0,
        wins: wins[p.$1] ?? 0,
        draws: draws[p.$1] ?? 0,
        losses: losses[p.$1] ?? 0,
        scored: scored[p.$1] ?? 0,
        conceded: conceded[p.$1] ?? 0,
        points: (total[p.$1] ?? 0).round(),
      ),
  ];
  return table..sort((a, b) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;
    final byDiff = (b.scored - b.conceded).compareTo(a.scored - a.conceded);
    if (byDiff != 0) return byDiff;
    return compareNames(a.player.$2, b.player.$2);
  });
}

/// Premier tour des playoffs, en [roundCount] tours, entre les premiers du
/// classement [table] : le 1er contre le dernier qualifié, le 2e contre
/// l'avant-dernier… placés pour que les meilleurs ne se croisent qu'à la
/// fin (le 1er et le 2e en finale). Null s'il n'y a pas assez de joueurs.
List<StoredMatch>? seedPlayoffs(List<Standing> table, int roundCount) {
  final count = 1 << roundCount;
  if (table.length < count) return null;
  // Ordre des têtes de série dans le tableau : 1, 2 ; puis 1, 4, 2, 3 ;
  // puis 1, 8, 4, 5, 2, 7, 3, 6…
  var seeds = [1];
  while (seeds.length < count) {
    final size = seeds.length * 2;
    seeds = [
      for (final s in seeds) ...[s, size + 1 - s],
    ];
  }
  return [
    for (var p = 0; p < count ~/ 2; p++)
      (
        round: 0,
        position: p,
        player1: table[seeds[2 * p] - 1].player.$1,
        player2: table[seeds[2 * p + 1] - 1].player.$1,
        party: null,
      ),
  ];
}
