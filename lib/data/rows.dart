import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'elo.dart';

/// Contenu d'une table prêt à afficher : les en-têtes de colonnes, puis une
/// liste de lignes (une cellule texte par colonne).
class RowTable {
  const RowTable({
    required this.columns,
    required this.rows,
    this.matchups,
    this.badges,
    this.forms,
    this.globalScores,
    this.matchLists,
    this.matchDetails,
    this.banners,
    this.lists,
    this.sortableLists = false,
    this.listForms,
  });

  final List<String> columns;
  final List<List<String>> rows;

  /// Libellé de chaque ligne dans la liste : sa première cellule.
  String title(int index) => rows[index].first;

  /// Pour les parties : chaque ligne de la liste montre le joueur 1, les
  /// scores et le joueur 2, au lieu de son libellé.
  final List<Matchup>? matchups;

  Matchup? matchup(int index) => matchups?[index];

  /// Nombre affiché dans une pastille à droite de chaque ligne de la liste
  /// (pour les jeux : le nombre de joueurs qui y ont joué).
  final List<int>? badges;

  int? badge(int index) => badges?[index];

  /// Résultats des dernières parties de chaque ligne, du plus ancien au plus
  /// récent, en pastilles à droite de la liste (pour les joueurs).
  final List<List<Outcome>>? forms;

  List<Outcome>? form(int index) => forms?[index];

  /// Score global de chaque ligne, affiché à droite des pastilles (pour les
  /// joueurs : voir [globalElo]). Null si la ligne n'en a pas.
  final List<int?>? globalScores;

  int? globalScore(int index) => globalScores?[index];

  /// Parties listées en bas du détail de chaque ligne (pour les joueurs :
  /// les siennes, de la plus récente à la plus ancienne).
  final List<List<MatchDetail>>? matchLists;

  List<MatchDetail> matchList(int index) => matchLists?[index] ?? const [];

  /// Pour les parties : chaque ligne est une partie, affichée en grand dans
  /// le détail, à la place de ses colonnes.
  final List<MatchDetail>? matchDetails;

  MatchDetail? matchDetail(int index) => matchDetails?[index];

  /// Chemin d'asset de l'image de bannière de chaque ligne (voir
  /// [bannerAsset]). Le fichier peut ne pas exister.
  final List<String?>? banners;

  String? banner(int index) => banners?[index];

  /// Liste affichée sous le détail de chaque ligne, au style de la liste de
  /// gauche (libellé, valeur) : ELO par jeu d'un joueur, classement d'un jeu.
  final List<List<(String, String)>>? lists;

  List<(String, String)> list(int index) => lists?[index] ?? const [];

  /// Pastilles des dernières parties de chaque élément des listes du détail
  /// (pour les joueurs : par jeu), dans l'ordre de [lists].
  final List<List<List<Outcome>>>? listForms;

  List<List<Outcome>>? listForm(int index) => listForms?[index];

  /// Les listes du détail ont un en-tête pour les trier par nom ou par
  /// valeur (pour les joueurs : leurs jeux).
  final bool sortableLists;

  /// Détail d'une ligne : chacune de ses colonnes, sauf le nom (déjà dans la
  /// liste).
  List<(String, String)> entries(int index) => [
    for (final (i, column) in columns.indexed)
      if (column != 'Nom') (column, rows[index][i]),
  ];
}

/// Résultat d'une partie pour un joueur.
enum Outcome { win, draw, loss }

/// Résultats des [count] dernières parties de [player], tous jeux confondus,
/// du plus ancien au plus récent. [games] est dans l'ordre chronologique.
List<Outcome> recentForm(List<EloGame> games, int player, {int count = 5}) {
  final outcomes = [
    for (final g in games)
      if (g.player1 == player || g.player2 == player)
        switch ((g.player1 == player ? 1 : -1) * g.score1.compareTo(g.score2)) {
          > 0 => Outcome.win,
          < 0 => Outcome.loss,
          _ => Outcome.draw,
        },
  ];
  return outcomes.sublist(max(0, outcomes.length - count));
}

/// Score global de [player] : la moyenne de ses ELO dans les jeux auxquels
/// il a joué, arrondie. Null s'il n'a joué à aucun jeu.
int? globalElo(Map<int, Map<int, double>> elo, int player) {
  final ratings = [for (final perGame in elo.values) ?perGame[player]];
  if (ratings.isEmpty) return null;
  return (ratings.reduce((a, b) => a + b) / ratings.length).round();
}

/// Une partie dans la liste : joueur 1, scores, joueur 2.
typedef Matchup = ({String player1, int score1, int score2, String player2});

/// Une partie détaillée : sa date, la partie, son jeu, son lieu, l'évolution
/// du ELO du joueur 1 (celle du joueur 2 est l'opposée) et les résultats des
/// 5 dernières parties de chaque joueur (voir [recentForm]).
typedef MatchDetail = ({
  DateTime date,
  Matchup matchup,
  String game,
  String? place,
  double eloDelta1,
  List<Outcome> form1,
  List<Outcome> form2,
});

/// Chemin d'asset de la bannière d'une ligne : `assets/bannieres/<table>/<id>.jpg`.
String bannerAsset(String table, int id) => 'assets/bannieres/$table/$id.jpg';

/// Toutes les parties, dans l'ordre chronologique, pour le calcul du ELO,
/// avec le lieu et la date de chacune (même ordre).
Future<({List<EloGame> games, List<String?> places, List<DateTime> dates})>
_fetchGames(SupabaseClient db) async {
  final rows = await db
      .from('partie')
      .select(
        'jeu_id, joueur1_id, joueur2_id, score_joueur1, score_joueur2, lieu, '
        'created_at',
      )
      .order('created_at', ascending: true)
      .order('id', ascending: true);
  return (
    games: [
      for (final r in rows)
        (
          game: r['jeu_id'] as int,
          player1: r['joueur1_id'] as int,
          player2: r['joueur2_id'] as int,
          score1: r['score_joueur1'] as int,
          score2: r['score_joueur2'] as int,
        ),
    ],
    places: [for (final r in rows) r['lieu'] as String?],
    dates: [for (final r in rows) DateTime.parse(r['created_at'] as String)],
  );
}

/// Lignes d'une table de la base, mises en colonnes.
///
/// Pour `partie` : les deux joueurs, leurs scores et le jeu.
/// Pour `joueur` : le nom, son ELO à chaque jeu auquel il a joué et ses
/// parties.
/// Pour `jeu` : le nom et le classement ELO des joueurs qui y ont joué.
/// Pour les autres tables : le nom.
Future<RowTable> fetchRows(String table) async {
  final db = Supabase.instance.client;

  if (table == 'partie') {
    final (players, boardGames, (:games, :places, :dates)) = await (
      db.from('joueur').select('id, nom'),
      db.from('jeu').select('id, nom'),
      _fetchGames(db),
    ).wait;
    final playerNames = {
      for (final p in players) p['id'] as int: p['nom'] as String,
    };
    final gameNames = {
      for (final j in boardGames) j['id'] as int: j['nom'] as String,
    };
    final deltas = eloDeltas(games);
    final forms = {
      for (final p in players)
        p['id'] as int: recentForm(games, p['id'] as int),
    };
    // De la plus récente à la plus ancienne.
    final recent = games.indexed.toList().reversed.toList();
    final details = [
      for (final (i, g) in recent)
        (
          date: dates[i],
          matchup: (
            player1: playerNames[g.player1]!,
            score1: g.score1,
            score2: g.score2,
            player2: playerNames[g.player2]!,
          ),
          game: gameNames[g.game]!,
          place: places[i],
          eloDelta1: deltas[i],
          form1: forms[g.player1]!,
          form2: forms[g.player2]!,
        ),
    ];
    return RowTable(
      // La bannière d'une partie est celle du jeu joué.
      banners: [for (final (_, g) in recent) bannerAsset('jeu', g.game)],
      matchups: [for (final d in details) d.matchup],
      matchDetails: details,
      columns: const ['Joueur 1', 'Score 1', 'Score 2', 'Joueur 2', 'Jeu'],
      rows: [
        for (final d in details)
          [
            d.matchup.player1,
            '${d.matchup.score1}',
            '${d.matchup.score2}',
            d.matchup.player2,
            d.game,
          ],
      ],
    );
  }

  if (table == 'joueur') {
    final (players, boardGames, (:games, :places, :dates)) = await (
      db.from('joueur').select('id, nom').order('nom', ascending: true),
      db.from('jeu').select('id, nom').order('nom', ascending: true),
      _fetchGames(db),
    ).wait;
    final elo = computeElo(games);
    final deltas = eloDeltas(games);
    final forms = {
      for (final p in players)
        p['id'] as int: recentForm(games, p['id'] as int),
    };
    final gameNames = {
      for (final j in boardGames) j['id'] as int: j['nom'] as String,
    };
    final playerNames = {
      for (final p in players) p['id'] as int: p['nom'] as String,
    };
    final gameIds = {
      for (final MapEntry(:key, :value) in gameNames.entries) value: key,
    };
    final playerLists = [
      for (final p in players) playerGames(elo, p['id'] as int, gameNames),
    ];
    return RowTable(
      sortableLists: true,
      // Pastilles par jeu : les 5 dernières parties du joueur à ce jeu.
      listForms: [
        for (final (i, p) in players.indexed)
          [
            for (final (name, _) in playerLists[i])
              recentForm([
                for (final g in games)
                  if (g.game == gameIds[name]) g,
              ], p['id'] as int),
          ],
      ],
      matchLists: [
        for (final p in players)
          [
            for (final (i, g) in games.indexed.toList().reversed)
              if (g.player1 == p['id'] || g.player2 == p['id'])
                (
                  date: dates[i],
                  matchup: (
                    player1: playerNames[g.player1]!,
                    score1: g.score1,
                    score2: g.score2,
                    player2: playerNames[g.player2]!,
                  ),
                  game: gameNames[g.game]!,
                  place: places[i],
                  eloDelta1: deltas[i],
                  form1: forms[g.player1]!,
                  form2: forms[g.player2]!,
                ),
          ],
      ],
      lists: playerLists,
      banners: [for (final p in players) bannerAsset(table, p['id'] as int)],
      forms: [for (final p in players) recentForm(games, p['id'] as int)],
      globalScores: [for (final p in players) globalElo(elo, p['id'] as int)],
      columns: const ['Nom'],
      rows: [
        for (final p in players) [p['nom'] as String],
      ],
    );
  }

  if (table == 'jeu') {
    final (boardGames, players, (:games, places: _, dates: _)) = await (
      db.from('jeu').select('id, nom').order('nom', ascending: true),
      db.from('joueur').select('id, nom').order('nom', ascending: true),
      _fetchGames(db),
    ).wait;
    final elo = computeElo(games);
    return RowTable(
      banners: [for (final j in boardGames) bannerAsset(table, j['id'] as int)],
      columns: const ['Nom'],
      rows: [
        for (final j in boardGames) [j['nom'] as String],
      ],
      // Le classement d'un jeu ne contient que les joueurs qui y ont joué.
      badges: [for (final j in boardGames) elo[j['id'] as int]?.length ?? 0],
      lists: [
        for (final j in boardGames)
          ranking(elo[j['id'] as int] ?? const {}, {
            for (final p in players) p['id'] as int: p['nom'] as String,
          }),
      ],
    );
  }

  final rows = await db
      .from(table)
      .select('id, nom')
      .order('nom', ascending: true);
  return RowTable(
    banners: [for (final r in rows) bannerAsset(table, r['id'] as int)],
    columns: const ['Nom'],
    rows: [
      for (final r in rows) [r['nom'] as String],
    ],
  );
}

/// Jeux auxquels [player] a joué, du meilleur ELO au moins bon, en (nom du
/// jeu, ELO), avec les noms pris dans [games] (id → nom). À ELO égal, par
/// nom.
List<(String, String)> playerGames(
  Map<int, Map<int, double>> elo,
  int player,
  Map<int, String> games,
) {
  final played = [
    for (final MapEntry(key: game, value: ratings) in elo.entries)
      if (ratings[player] case final rating?) (games[game]!, rating),
  ]..sort(_byEloThenName);
  return [for (final (name, rating) in played) (name, '${rating.round()}')];
}

/// Du meilleur ELO au moins bon ; à ELO égal, par nom.
int _byEloThenName((String, double) a, (String, double) b) {
  final byElo = b.$2.compareTo(a.$2);
  return byElo != 0 ? byElo : a.$1.compareTo(b.$1);
}

/// Classement ELO d'un jeu : les joueurs qui y ont joué (présents dans
/// [ratings]), du meilleur au moins bon, en (« rang. nom », ELO), avec leur
/// nom pris dans [players] (id → nom). À ELO égal, par nom.
List<(String, String)> ranking(
  Map<int, double> ratings,
  Map<int, String> players,
) {
  final ranked = [
    for (final MapEntry(key: id, value: elo) in ratings.entries)
      (players[id]!, elo),
  ]..sort(_byEloThenName);
  return [
    for (final (i, (name, elo)) in ranked.indexed)
      ('${i + 1}. $name', '${elo.round()}'),
  ];
}
