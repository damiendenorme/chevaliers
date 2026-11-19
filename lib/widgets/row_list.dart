import 'package:flutter/material.dart';

import '../data/rows.dart';
import 'top_bar.dart';

/// Tableau dense des lignes d'une table, au style de la barre de menu.
///
/// Remplit toute la zone qu'on lui donne (voir [width], la largeur prévue
/// pour tous les tableaux) : son pied reste donc fixe quel que soit le nombre
/// de lignes, et ce sont les lignes qui défilent à l'intérieur.
/// Gère aussi le chargement, l'erreur et le cas vide, dans la même zone.
class RowList extends StatelessWidget {
  const RowList({super.key, required this.rows});

  static const double width = 1000;

  final Future<RowTable> rows;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(color: topBarColor, child: _content()),
    );
  }

  Widget _content() {
    return FutureBuilder<RowTable>(
      future: rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Message('Impossible de charger les données.');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final table = snapshot.data!;
        if (table.rows.isEmpty) return const _Message('Aucune ligne.');
        return SingleChildScrollView(child: _DenseTable(table));
      },
    );
  }
}

class _DenseTable extends StatelessWidget {
  const _DenseTable(this.table);

  final RowTable table;

  static const _text = TextStyle(fontSize: 14);

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(
      color: Theme.of(context).scaffoldBackgroundColor,
    );
    final headerColor = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget cell(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(text, style: _text.copyWith(color: color), softWrap: false),
    );

    return Table(
      // Les colonnes se partagent toute la largeur du tableau.
      defaultColumnWidth: const FlexColumnWidth(),
      border: TableBorder(horizontalInside: divider),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: topBarColor),
          children: [
            for (final c in table.columns) cell(c, color: headerColor),
          ],
        ),
        for (final row in table.rows)
          TableRow(
            decoration: const BoxDecoration(color: topBarColor),
            children: [for (final v in row) cell(v)],
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
