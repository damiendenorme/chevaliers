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
    this.globalScoreLabel = 'Score',
    this.matchLists,
    this.matchDetails,
    this.photos,
    this.matchListShowsGame = true,
    this.dates,
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

  /// Nom du score global dans l'en-tête de la liste : « Score » (Wargame),
  /// « Gloire » (RPG).
  final String globalScoreLabel;

  /// Parties listées en bas du détail de chaque ligne (pour les joueurs :
  /// les siennes, de la plus récente à la plus ancienne).
  final List<List<MatchDetail>>? matchLists;

  List<MatchDetail> matchList(int index) => matchLists?[index] ?? const [];

  /// Les parties du détail affichent leur jeu (pas pour un jeu : ce sont
  /// toutes les siennes).
  final bool matchListShowsGame;

  /// Pour les parties : chaque ligne est une partie, affichée en grand dans
  /// le détail, à la place de ses colonnes.
  final List<MatchDetail>? matchDetails;

  MatchDetail? matchDetail(int index) => matchDetails?[index];

  /// Pour les parties : URL des photos de chaque ligne (0 à plusieurs),
  /// affichées dans une zone du détail. Null : pas de zone de photos.
  final List<List<String>>? photos;

  List<String>? photosOf(int index) => photos?[index];

  /// Date de chaque ligne, affichée à droite dans la liste, qui peut être
  /// triée par nom ou par date (pour les événements). Null si elle n'en a
  /// pas.
  final List<DateTime?>? dates;

  DateTime? date(int index) => dates?[index];

  /// Chemin d'asset de l'image de bannière de chaque ligne, sans extension
  /// (voir [bannerAsset]). Le fichier peut ne pas exister.
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

/// Parties détaillées (voir [MatchDetail]), de la plus récente à la plus
/// ancienne : toutes, ou seulement celles qui vérifient [where]. [games],
/// [places] et [dates] sont dans l'ordre chronologique.
List<MatchDetail> _matchDetails({
  required List<EloGame> games,
  required List<String?> places,
  required List<DateTime> dates,
  required Map<int, String> playerNames,
  required Map<int, String> gameNames,
  bool Function(EloGame game)? where,
  double start = eloStart,
}) {
  final deltas = eloDeltas(games, start: start);
  final forms = {for (final id in playerNames.keys) id: recentForm(games, id)};
  return [
    for (final (i, g) in games.indexed.toList().reversed)
      if (where?.call(g) ?? true)
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
}

/// Chemin d'asset de la bannière d'une ligne, sans extension :
/// `assets/bannieres/<table>/<id>`. Le fichier peut être en .jpg, .jpeg ou
/// .png (voir [resolveImageAsset]).
String bannerAsset(String table, int id) => 'assets/bannieres/$table/$id';

/// Extensions d'image reconnues, dans l'ordre de préférence.
const imageExtensions = ['jpg', 'jpeg', 'png'];

/// Fichier de [assets] (la liste des assets de l'app) qui correspond à
/// [base] avec une extension d'image reconnue, quelle que soit la casse de
/// l'extension. Null s'il n'y en a pas.
String? resolveImageAsset(String base, Iterable<String> assets) {
  final byLowerCase = {for (final a in assets) a.toLowerCase(): a};
  for (final ext in imageExtensions) {
    if (byLowerCase['${base.toLowerCase()}.$ext'] case final found?) {
      return found;
    }
  }
  return null;
}

/// ELO de départ selon les données : 0 au RPG (la Gloire), 1000 sinon.
double _start(String prefix) => prefix == 'rpg_' ? rpgEloStart : eloStart;

/// Toutes les parties, dans l'ordre chronologique, pour le calcul du ELO,
/// avec le lieu, la date et l'id de chacune (même ordre).
Future<
  ({
    List<EloGame> games,
    List<String?> places,
    List<DateTime> dates,
    List<int> ids,
  })
>
_fetchGames(SupabaseClient db, String prefix) async {
  final rows = await db
      .from('${prefix}partie')
      .select(
        'id, jeu_id, joueur1_id, joueur2_id, score_joueur1, score_joueur2, '
        'lieu, created_at',
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
    ids: [for (final r in rows) r['id'] as int],
  );
}

/// Lignes d'une table de la base, mises en colonnes.
///
/// Pour `partie` : les deux joueurs, leurs scores et le jeu.
/// Pour `joueur` : le nom, son ELO à chaque jeu auquel il a joué et ses
/// parties.
/// Pour `evenement` : le nom et la date.
/// Pour `jeu` : le nom, le classement ELO des joueurs qui y ont joué et ses
/// parties.
/// Pour les autres tables : le nom.
///
/// [prefix] : préfixe des tables, vide pour le Wargame, `rpg_` pour le RPG
/// (données séparées, même structure). Les bannières suivent le même
/// préfixe : `assets/bannieres/rpg_jeu/<id>`…
Future<RowTable> fetchRows(String table, {String prefix = ''}) async {
  final db = Supabase.instance.client;

  if (table == 'partie') {
    final (
      players,
      boardGames,
      (:games, :places, :dates, :ids),
      photoRows,
    ) = await (
      db.from('${prefix}joueur').select('id, nom'),
      db.from('${prefix}jeu').select('id, nom'),
      _fetchGames(db, prefix),
      db
          .from('${prefix}photo')
          .select('partie_id, chemin')
          .order('created_at', ascending: true)
          .order('id', ascending: true),
    ).wait;
    // URL publique de chaque photo, par partie.
    final photosByGame = <int, List<String>>{};
    for (final r in photoRows) {
      photosByGame
          .putIfAbsent(r['partie_id'] as int, () => [])
          .add(db.storage.from('photos').getPublicUrl(r['chemin'] as String));
    }
    final playerNames = {
      for (final p in players) p['id'] as int: p['nom'] as String,
    };
    final gameNames = {
      for (final j in boardGames) j['id'] as int: j['nom'] as String,
    };
    final details = _matchDetails(
      start: _start(prefix),
      games: games,
      places: places,
      dates: dates,
      playerNames: playerNames,
      gameNames: gameNames,
    );
    // Mêmes positions que [details] : de la plus récente à la plus ancienne.
    final recent = games.indexed.toList().reversed.toList();
    return RowTable(
      // La bannière d'une partie est celle du jeu joué.
      banners: [
        for (final (_, g) in recent) bannerAsset('${prefix}jeu', g.game),
      ],
      matchups: [for (final d in details) d.matchup],
      matchDetails: details,
      photos: [for (final (i, _) in recent) photosByGame[ids[i]] ?? const []],
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
    final (players, boardGames, (:games, :places, :dates, ids: _)) = await (
      db
          .from('${prefix}joueur')
          .select('id, nom')
          .order('nom', ascending: true),
      db.from('${prefix}jeu').select('id, nom').order('nom', ascending: true),
      _fetchGames(db, prefix),
    ).wait;
    final elo = computeElo(games, start: _start(prefix));
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
          _matchDetails(
            start: _start(prefix),
            games: games,
            places: places,
            dates: dates,
            playerNames: playerNames,
            gameNames: gameNames,
            where: (g) => g.player1 == p['id'] || g.player2 == p['id'],
          ),
      ],
      lists: playerLists,
      banners: [
        for (final p in players) bannerAsset('$prefix$table', p['id'] as int),
      ],
      forms: [for (final p in players) recentForm(games, p['id'] as int)],
      // Sans partie : rien au Wargame ; au RPG, la Gloire de départ, 0.
      globalScores: [
        for (final p in players)
          globalElo(elo, p['id'] as int) ??
              (prefix == 'rpg_' ? rpgEloStart.round() : null),
      ],
      // Au RPG, le score général d'un joueur s'appelle la Gloire.
      globalScoreLabel: prefix == 'rpg_' ? 'Gloire' : 'Score',
      columns: const ['Nom'],
      rows: [
        for (final p in players) [p['nom'] as String],
      ],
    );
  }

  if (table == 'jeu') {
    final (boardGames, players, (:games, :places, :dates, ids: _)) = await (
      db.from('${prefix}jeu').select('id, nom').order('nom', ascending: true),
      db
          .from('${prefix}joueur')
          .select('id, nom')
          .order('nom', ascending: true),
      _fetchGames(db, prefix),
    ).wait;
    final elo = computeElo(games, start: _start(prefix));
    final playerNames = {
      for (final p in players) p['id'] as int: p['nom'] as String,
    };
    final gameNames = {
      for (final j in boardGames) j['id'] as int: j['nom'] as String,
    };
    return RowTable(
      matchListShowsGame: false,
      // Sous le classement : les parties jouées à ce jeu.
      matchLists: [
        for (final j in boardGames)
          _matchDetails(
            start: _start(prefix),
            games: games,
            places: places,
            dates: dates,
            playerNames: playerNames,
            gameNames: gameNames,
            where: (g) => g.game == j['id'],
          ),
      ],
      banners: [
        for (final j in boardGames)
          bannerAsset('$prefix$table', j['id'] as int),
      ],
      columns: const ['Nom'],
      rows: [
        for (final j in boardGames) [j['nom'] as String],
      ],
      // Le classement d'un jeu ne contient que les joueurs qui y ont joué.
      badges: [for (final j in boardGames) elo[j['id'] as int]?.length ?? 0],
      lists: [
        for (final j in boardGames)
          ranking(elo[j['id'] as int] ?? const {}, playerNames),
      ],
      // Pastilles de chaque joueur classé : ses 5 dernières parties à ce jeu.
      listForms: [
        for (final j in boardGames)
          [
            for (final id in rankedPlayers(
              elo[j['id'] as int] ?? const {},
              playerNames,
            ))
              recentForm([
                for (final g in games)
                  if (g.game == j['id']) g,
              ], id),
          ],
      ],
    );
  }

  if (table == 'evenement') {
    final rows = await db
        .from('${prefix}evenement')
        .select('id, nom, date')
        .order('nom', ascending: true);
    final dates = [
      for (final r in rows)
        if (r['date'] case final String d) DateTime.parse(d) else null,
    ];
    return RowTable(
      banners: [
        for (final r in rows) bannerAsset('$prefix$table', r['id'] as int),
      ],
      dates: dates,
      columns: const ['Nom', 'Date'],
      rows: [
        for (final (i, r) in rows.indexed)
          [
            r['nom'] as String,
            if (dates[i] case final d?) formatMonth(d) else '—',
          ],
      ],
    );
  }

  final rows = await db
      .from('$prefix$table')
      .select('id, nom')
      .order('nom', ascending: true);
  return RowTable(
    banners: [
      for (final r in rows) bannerAsset('$prefix$table', r['id'] as int),
    ],
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
  return byElo != 0 ? byElo : compareNames(a.$1, b.$1);
}

/// Classement ELO d'un jeu : les joueurs qui y ont joué (présents dans
/// [ratings]), du meilleur au moins bon, en (« rang. nom », ELO), avec leur
/// nom pris dans [players] (id → nom). À ELO égal, par nom.
List<(String, String)> ranking(
  Map<int, double> ratings,
  Map<int, String> players,
) => [
  for (final (i, id) in rankedPlayers(ratings, players).indexed)
    ('${i + 1}. ${players[id]}', '${ratings[id]!.round()}'),
];

/// Ids des joueurs de [ratings], dans l'ordre du classement (voir [ranking]).
List<int> rankedPlayers(Map<int, double> ratings, Map<int, String> players) {
  final ranked = [
    for (final MapEntry(key: id, value: elo) in ratings.entries)
      (id, (players[id]!, elo)),
  ]..sort((a, b) => _byEloThenName(a.$2, b.$2));
  return [for (final (id, _) in ranked) id];
}

/// Ordre alphabétique des noms, à la française : sans tenir compte des
/// accents ni de la casse (« Échecs » avant « Go »). À égalité, l'ordre brut.
int compareNames(String a, String b) {
  final byKey = _nameKey(a).compareTo(_nameKey(b));
  return byKey != 0 ? byKey : a.compareTo(b);
}

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ì': 'i',
  'ñ': 'n',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ò': 'o',
  'õ': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'ý': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

String _nameKey(String name) =>
    [for (final c in name.toLowerCase().split('')) _accents[c] ?? c].join();

/// Date au format JJ/MM/AA, dans le fuseau de l'appareil.
String formatDate(DateTime date) {
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${two(d.year % 100)}';
}

const _months = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

/// Mois et année, sans le jour : « Décembre 2027 » (dates d'événements).
String formatMonth(DateTime date) => '${_months[date.month - 1]} ${date.year}';
