import 'package:supabase_flutter/supabase_flutter.dart';

/// Contenu d'une table prêt à afficher : les en-têtes de colonnes, puis une
/// liste de lignes (une cellule texte par colonne).
class RowTable {
  const RowTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;
}

/// Lignes d'une table de la base, mises en colonnes.
///
/// Pour `partie` : les deux joueurs, leurs scores et le jeu.
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

  final rows = await db.from(table).select('nom').order('nom');
  return RowTable(
    columns: const ['Nom'],
    rows: [
      for (final r in rows) [r['nom'] as String],
    ],
  );
}
