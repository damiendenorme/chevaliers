import 'package:flutter/material.dart';

import '../data/rows.dart';
import 'top_bar.dart';

/// Liste des lignes d'une table à gauche, détail de la ligne choisie à
/// droite, au style de la barre de menu.
///
/// Remplit toute la zone qu'on lui donne (voir [width], la largeur prévue
/// pour tous les tableaux) : son pied reste donc fixe quel que soit le nombre
/// de lignes, et ce sont la liste et le détail qui défilent à l'intérieur.
/// Gère aussi le chargement, l'erreur et le cas vide, dans la même zone.
class RowList extends StatelessWidget {
  const RowList({super.key, required this.rows});

  static const double width = 1000;

  /// Largeur de la liste, à gauche.
  static const double listWidth = 300;

  final Future<RowTable> rows;

  @override
  Widget build(BuildContext context) {
    // Coins arrondis ; le contenu (ligne active, survol) est découpé avec.
    return SizedBox.expand(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(color: topBarColor, child: _content()),
      ),
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
        return _MasterDetail(table);
      },
    );
  }
}

const _text = TextStyle(fontSize: 14);
const _cellPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 4);

class _MasterDetail extends StatefulWidget {
  const _MasterDetail(this.table);

  final RowTable table;

  @override
  State<_MasterDetail> createState() => _MasterDetailState();
}

class _MasterDetailState extends State<_MasterDetail> {
  /// Ligne affichée à droite, ou null tant qu'aucune n'est choisie.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final divider = BorderSide(
      color: Theme.of(context).scaffoldBackgroundColor,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: RowList.listWidth,
          decoration: BoxDecoration(border: Border(right: divider)),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < table.rows.length; i++)
                  Material(
                    color: i == _selected ? accentColor : topBarColor,
                    shape: Border(bottom: divider),
                    child: InkWell(
                      onTap: () => setState(() => _selected = i),
                      hoverColor: hoverColor,
                      child: Padding(
                        padding: _cellPadding,
                        child: Text(
                          table.title(i),
                          style: i == _selected
                              ? _text.copyWith(color: Colors.white)
                              : _text,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _selected == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Banner(table.banner(_selected!)),
                      _Detail(table.entries(_selected!)),
                      _LineList(table.list(_selected!)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Bannière en haut du détail : l'image (asset) de la ligne sur toute la
/// largeur. Sans fichier, un bandeau vide de même taille.
class _Banner extends StatelessWidget {
  const _Banner(this.asset);

  static const double height = 160;

  final String? asset;

  @override
  Widget build(BuildContext context) {
    final empty = ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    return SizedBox(
      height: height,
      child: asset == null
          ? empty
          : Image.asset(
              asset!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => empty,
            ),
    );
  }
}

/// Liste au style de la liste de gauche : une ligne par élément, son libellé
/// à gauche et sa valeur à droite.
class _LineList extends StatelessWidget {
  const _LineList(this.lines);

  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(
      color: Theme.of(context).scaffoldBackgroundColor,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (name, value) in lines)
          DecoratedBox(
            decoration: BoxDecoration(border: Border(bottom: divider)),
            child: Padding(
              padding: _cellPadding,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: _text,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(value, style: _text),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Détail d'une ligne, en liste : pour chaque information, son nom puis sa
/// valeur dessous. Le nom de la ligne n'est pas repris : il est déjà dans la
/// liste de gauche.
class _Detail extends StatelessWidget {
  const _Detail(this.entries);

  /// Informations affichées : (libellé, valeur).
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in entries)
            Padding(
              padding: _cellPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: _text.copyWith(fontSize: 12, color: labelColor),
                  ),
                  Text(value, style: _text),
                ],
              ),
            ),
        ],
      ),
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
      child: Text(text, style: _text),
    );
  }
}
