import 'package:flutter/material.dart';

import '../data/rows.dart';
import 'top_bar.dart';

/// Liste des lignes d'une table à gauche, détail de la ligne choisie à
/// droite, chacun dans sa carte, au style de la barre de menu.
///
/// Remplit toute la zone qu'on lui donne (voir [width], la largeur prévue
/// pour tous les tableaux) : son pied reste donc fixe quel que soit le nombre
/// de lignes, et ce sont la liste et le détail qui défilent à l'intérieur.
/// Gère aussi le chargement, l'erreur et le cas vide, dans la carte de la
/// liste.
class RowList extends StatelessWidget {
  const RowList({super.key, required this.rows});

  static const double width = 1000;

  /// Largeur de la carte de la liste, à gauche.
  static const double listWidth = 300;

  /// Écart entre la carte de la liste et celle du détail.
  static const double gap = 12;

  final Future<RowTable> rows;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: _content());
  }

  Widget _content() {
    return FutureBuilder<RowTable>(
      future: rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Cards(
            master: _Message('Impossible de charger les données.'),
          );
        }
        if (!snapshot.hasData) {
          return const _Cards(
            master: Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        final table = snapshot.data!;
        if (table.rows.isEmpty) {
          return const _Cards(master: _Message('Aucune ligne.'));
        }
        return _MasterDetail(table);
      },
    );
  }
}

/// Les deux cartes côte à côte : la liste à gauche, le détail à droite.
class _Cards extends StatelessWidget {
  const _Cards({required this.master, this.detail});

  final Widget master;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RowList.gap,
      children: [
        SizedBox(width: RowList.listWidth, child: _Card(master)),
        Expanded(child: _Card(detail ?? const SizedBox.shrink())),
      ],
    );
  }
}

/// Carte au style de la barre de menu, à coins arrondis et légère ombre ; son
/// contenu (ligne active, survol) est découpé avec.
class _Card extends StatelessWidget {
  const _Card(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    // L'ombre est posée hors du découpage, pour ne pas être coupée.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: lightShadow),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(color: topBarColor, child: child),
      ),
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

    return _Cards(
      master: SingleChildScrollView(
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
                    child: _MasterLine(
                      table,
                      i,
                      style: i == _selected
                          ? _text.copyWith(color: Colors.white)
                          : _text,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      detail: _selected == null
          ? null
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
    );
  }
}

/// Contenu d'une ligne de la liste : son libellé, ou pour une partie, le
/// joueur 1 à gauche, les scores au milieu et le joueur 2 à droite. Le
/// gagnant et son score sont en gras, le perdant et son score grisés ; à
/// égalité, aucun des deux.
class _MasterLine extends StatelessWidget {
  const _MasterLine(this.table, this.index, {required this.style});

  final RowTable table;
  final int index;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    Text text(String value, {TextStyle? style, TextAlign? align}) => Text(
      value,
      style: style ?? this.style,
      textAlign: align,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    final m = table.matchup(index);
    final badge = table.badge(index);
    if (m == null && badge != null) {
      return Row(
        spacing: 8,
        children: [
          Expanded(child: text(table.title(index))),
          _Badge(badge, style: style),
        ],
      );
    }
    if (m == null) return text(table.title(index));

    final color = style.color ?? DefaultTextStyle.of(context).style.color!;
    final winner = style.copyWith(fontWeight: FontWeight.bold);
    final loser = style.copyWith(color: color.withValues(alpha: 0.45));
    final (style1, style2) = switch (m.score1.compareTo(m.score2)) {
      > 0 => (winner, loser),
      < 0 => (loser, winner),
      _ => (style, style),
    };

    // Les deux joueurs, puis les deux scores, ont la même largeur : le tiret
    // entre les scores reste au milieu.
    return Row(
      spacing: 8,
      children: [
        Expanded(child: text(m.player1, style: style1)),
        SizedBox(
          width: 20,
          child: text('${m.score1}', style: style1, align: TextAlign.right),
        ),
        Text('–', style: style),
        SizedBox(width: 20, child: text('${m.score2}', style: style2)),
        Expanded(
          child: text(m.player2, style: style2, align: TextAlign.right),
        ),
      ],
    );
  }
}

/// Pastille avec un nombre, sur un fond légèrement teinté de la couleur du
/// texte (lisible aussi sur la ligne active).
class _Badge extends StatelessWidget {
  const _Badge(this.value, {required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final color = style.color ?? DefaultTextStyle.of(context).style.color!;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$value',
        style: style.copyWith(fontSize: 12),
        textAlign: TextAlign.center,
      ),
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
