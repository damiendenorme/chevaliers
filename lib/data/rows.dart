import 'package:supabase_flutter/supabase_flutter.dart';

/// Contenu d'une table prêt à afficher : les en-têtes de colonnes, puis une
/// liste de lignes (une cellule texte par colonne).
class RowTable {
  const RowTable({required this.columns, required this.rows, this.titles});

  final List<String> columns;
  final List<List<String>> rows;

  /// Libellé de chaque ligne dans la liste. Par défaut, sa première cellule.
  final List<String>? titles;

  String title(int index) => titles?[index] ?? rows[index].first;
}

/// Lignes d'une table de la base, mises en colonnes.
///
/// Pour `partie` : les deux joueurs, leurs scores et le jeu.
/// Pour `joueur` : le nom et le jeu favori.
/// Pour les autres tables : le nom.
Future<RowTable> fetchRows(String table) async {
  final db = Supabase.instance.client;

  if (table == 'partie') {
    final rows = await db
        .from('partie')
        .select(
          'score_joueur1, score_joueur2, jeu(nom), '
          'joueur1:joueur!partie_joueur1_id_fkey(nom), '
          'joueur2:joueur!partie_joueur2_id_fkey(nom)',
        )
        .order('created_at', ascending: false);
    return RowTable(
      titles: [
        for (final r in rows) '${r['joueur1']['nom']} – ${r['joueur2']['nom']}',
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
    final (players, games) = await (
      db.from('joueur').select('id, nom').order('nom', ascending: true),
      db.from('partie').select('joueur1_id, joueur2_id, jeu(nom)'),
    ).wait;
    final played = [
      for (final g in games)
        (
          g['joueur1_id'] as int,
          g['joueur2_id'] as int,
          g['jeu']['nom'] as String,
        ),
    ];
    return RowTable(
      columns: const ['Nom', 'Jeu favori'],
      rows: [
        for (final p in players)
          [p['nom'] as String, favoriteGame(p['id'] as int, played) ?? '—'],
      ],
    );
  }

  final rows = await db.from(table).select('nom').order('nom', ascending: true);
  return RowTable(
    columns: const ['Nom'],
    rows: [
      for (final r in rows) [r['nom'] as String],
    ],
  );
}

/// Jeu auquel [playerId] a joué le plus de parties, parmi [games]
/// (joueur 1, joueur 2, nom du jeu). En cas d'égalité, le premier par ordre
/// alphabétique. Null si le joueur n'a joué aucune partie.
String? favoriteGame(int playerId, List<(int, int, String)> games) {
  final counts = <String, int>{};
  for (final (p1, p2, game) in games) {
    if (p1 == playerId || p2 == playerId) {
      counts[game] = (counts[game] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return ranked.first.key;
}
