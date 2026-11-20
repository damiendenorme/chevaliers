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
    this.banners,
    this.lists,
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

  /// Chemin d'asset de l'image de bannière de chaque ligne (voir
  /// [bannerAsset]). Le fichier peut ne pas exister.
  final List<String?>? banners;

  String? banner(int index) => banners?[index];

  /// Liste affichée sous le détail de chaque ligne, au style de la liste de
  /// gauche (libellé, valeur) : ELO par jeu d'un joueur, classement d'un jeu.
  final List<List<(String, String)>>? lists;

  List<(String, String)> list(int index) => lists?[index] ?? const [];

  /// Détail d'une ligne : chacune de ses colonnes, sauf le nom (déjà dans la
  /// liste).
  List<(String, String)> entries(int index) => [
    for (final (i, column) in columns.indexed)
      if (column != 'Nom') (column, rows[index][i]),
  ];
}

/// Une partie dans la liste : joueur 1, scores, joueur 2.
typedef Matchup = ({String player1, int score1, int score2, String player2});

/// Chemin d'asset de la bannière d'une ligne : `assets/bannieres/<table>/<id>.jpg`.
String bannerAsset(String table, int id) => 'assets/bannieres/$table/$id.jpg';

/// Toutes les parties, dans l'ordre chronologique, pour le calcul du ELO.
Future<List<EloGame>> _fetchEloGames(SupabaseClient db) async {
  final rows = await db
      .from('partie')
      .select('jeu_id, joueur1_id, joueur2_id, score_joueur1, score_joueur2')
      .order('created_at', ascending: true)
      .order('id', ascending: true);
  return [
    for (final r in rows)
      (
        game: r['jeu_id'] as int,
        player1: r['joueur1_id'] as int,
        player2: r['joueur2_id'] as int,
        score1: r['score_joueur1'] as int,
        score2: r['score_joueur2'] as int,
      ),
  ];
}

/// Lignes d'une table de la base, mises en colonnes.
///
/// Pour `partie` : les deux joueurs, leurs scores et le jeu.
/// Pour `joueur` : le nom et son ELO à chaque jeu auquel il a joué.
/// Pour `jeu` : le nom et le classement ELO des joueurs qui y ont joué.
/// Pour les autres tables : le nom.
Future<RowTable> fetchRows(String table) async {
  final db = Supabase.instance.client;

  if (table == 'partie') {
    final rows = await db
        .from('partie')
        .select(
          'jeu_id, score_joueur1, score_joueur2, jeu(nom), '
          'joueur1:joueur!partie_joueur1_id_fkey(nom), '
          'joueur2:joueur!partie_joueur2_id_fkey(nom)',
        )
        .order('created_at', ascending: false);
    return RowTable(
      // La bannière d'une partie est celle du jeu joué.
      banners: [for (final r in rows) bannerAsset('jeu', r['jeu_id'] as int)],
      matchups: [
        for (final r in rows)
          (
            player1: r['joueur1']['nom'] as String,
            score1: r['score_joueur1'] as int,
            score2: r['score_joueur2'] as int,
            player2: r['joueur2']['nom'] as String,
          ),
      ],
      columns: const ['Joueur 1', 'Score 1', 'Score 2', 'Joueur 2', 'Jeu'],
      rows: [
        for (final r in rows)
          [
            r['joueur1']['nom'] as String,
            '${r['score_joueur1']}',
            '${r['score_joueur2']}',
            r['joueur2']['nom'] as String,
            r['jeu']['nom'] as String,
          ],
      ],
    );
  }

  if (table == 'joueur') {
    final (players, boardGames, games) = await (
      db.from('joueur').select('id, nom').order('nom', ascending: true),
      db.from('jeu').select('id, nom').order('nom', ascending: true),
      _fetchEloGames(db),
    ).wait;
    final elo = computeElo(games);
    final gameNames = {
      for (final j in boardGames) j['id'] as int: j['nom'] as String,
    };
    return RowTable(
      lists: [
        for (final p in players) playerGames(elo, p['id'] as int, gameNames),
      ],
      banners: [for (final p in players) bannerAsset(table, p['id'] as int)],
      columns: const ['Nom'],
      rows: [
        for (final p in players) [p['nom'] as String],
      ],
    );
  }

  if (table == 'jeu') {
    final (boardGames, players, games) = await (
      db.from('jeu').select('id, nom').order('nom', ascending: true),
      db.from('joueur').select('id, nom').order('nom', ascending: true),
      _fetchEloGames(db),
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
