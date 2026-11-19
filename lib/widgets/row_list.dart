import 'package:flutter/material.dart';

import '../data/rows.dart';
import 'top_bar.dart';

/// Tableau dense des lignes d'une table, centré à l'écran, au style de la
/// barre de menu. Gère aussi le chargement, l'erreur et le cas vide.
class RowList extends StatelessWidget {
  const RowList({super.key, required this.rows});

  final Future<RowTable> rows;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RowTable>(
      future: rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Message('Impossible de charger les données.');
        }
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final table = snapshot.data!;
        if (table.rows.isEmpty) return const _Message('Aucune ligne.');
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _DenseTable(table),
          ),
        );
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
      defaultColumnWidth: const IntrinsicColumnWidth(),
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
    return Center(child: Text(text, style: const TextStyle(fontSize: 14)));
  }
}
