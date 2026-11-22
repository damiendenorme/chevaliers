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
          // Chargement : spinner au centre de la carte.
          return const _Cards(
            master: Center(
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
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

/// Carte sombre à coins arrondis, liseré bronze et légère ombre ; son contenu
/// (ligne active, survol) est découpé avec.
class _Card extends StatelessWidget {
  const _Card(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    // L'ombre est posée hors du découpage, pour ne pas être coupée ; le
    // liseré bronze par-dessus le contenu.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: lightShadow),
      position: DecorationPosition.background,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: edgeColor),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(color: topBarColor, child: child),
        ),
      ),
    );
  }
}

const _text = TextStyle(fontSize: 14);

/// Largeur des colonnes de scores ELO (4 chiffres), alignés à droite.
const double _scoreWidth = 44;
const _cellPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 4);

class _MasterDetail extends StatefulWidget {
  const _MasterDetail(this.table);

  final RowTable table;

  @override
  State<_MasterDetail> createState() => _MasterDetailState();
}

/// Colonne de tri de la liste.
enum _SortBy { name, score }

class _MasterDetailState extends State<_MasterDetail> {
  /// Ligne affichée à droite, ou null tant qu'aucune n'est choisie.
  int? _selected;

  /// Tri de la liste (s'il y a des scores) : par score décroissant au
  /// départ.
  _SortBy _sortBy = _SortBy.score;
  bool _ascending = false;

  /// Cliquer sur la colonne déjà triée inverse le sens ; sur l'autre, trie
  /// par nom de A à Z, ou par score du meilleur au moins bon.
  void _sort(_SortBy by) {
    setState(() {
      _ascending = by == _sortBy ? !_ascending : by == _SortBy.name;
      _sortBy = by;
    });
  }

  /// Positions des lignes dans l'ordre affiché. Sans score, toujours en
  /// dernier.
  List<int> _order(RowTable table) {
    final order = [for (var i = 0; i < table.rows.length; i++) i];
    if (table.globalScores == null) return order;
    final direction = _ascending ? 1 : -1;
    return order..sort((a, b) {
      if (_sortBy == _SortBy.score) {
        final (sa, sb) = (table.globalScore(a), table.globalScore(b));
        if (sa == null || sb == null) {
          if (sa != sb) return sa == null ? 1 : -1;
        } else if (sa != sb) {
          return direction * sa.compareTo(sb);
        }
      }
      return (_sortBy == _SortBy.name ? direction : 1) *
          table.title(a).compareTo(table.title(b));
    });
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    const divider = BorderSide(color: dividerColor);

    final list = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in _order(table))
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
    );

    return _Cards(
      // Avec des scores : un en-tête fixe au-dessus de la liste, pour la
      // trier par nom ou par score.
      master: table.globalScores == null
          ? list
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(border: Border(bottom: divider)),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SortHeader(
                          'Nom',
                          arrow: _sortBy == _SortBy.name ? _ascending : null,
                          onTap: () => _sort(_SortBy.name),
                        ),
                      ),
                      _SortHeader(
                        'Score',
                        arrow: _sortBy == _SortBy.score ? _ascending : null,
                        onTap: () => _sort(_SortBy.score),
                      ),
                    ],
                  ),
                ),
                Expanded(child: list),
              ],
            ),
      detail: _selected == null
          ? null
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Banner(table.banner(_selected!)),
                  _Detail(table.entries(_selected!)),
                  // Une clé par ligne : le tri repart de zéro à chaque
                  // changement de ligne.
                  _LineList(
                    key: ValueKey(_selected),
                    table.list(_selected!),
                    sortable: table.sortableLists,
                    forms: table.listForm(_selected!),
                  ),
                  _MatchupList(
                    key: ValueKey(('parties', _selected)),
                    table.matchList(_selected!),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Contenu d'une ligne de la liste : son libellé (avec pastille, ou forme et
/// score), ou pour une partie, voir [_MatchupLine].
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
    final form = table.form(index);
    if (m == null && form != null) {
      final score = table.globalScore(index);
      return Row(
        spacing: 8,
        children: [
          Expanded(child: text(table.title(index))),
          _Form(form),
          // Largeur fixe : les scores restent alignés d'une ligne à l'autre.
          SizedBox(
            width: _scoreWidth,
            child: text(score?.toString() ?? '', align: TextAlign.right),
          ),
        ],
      );
    }
    if (m == null) return text(table.title(index));
    return _MatchupLine(m, style: style);
  }
}

/// Une partie sur une ligne : le joueur 1 à gauche, les scores au milieu et
/// le joueur 2 à droite. Le gagnant et son score sont en gras, le perdant et
/// son score grisés ; à égalité, aucun des deux.
class _MatchupLine extends StatelessWidget {
  const _MatchupLine(this.m, {required this.style, this.eloDelta1});

  final Matchup m;
  final TextStyle style;

  /// Évolution du ELO du joueur 1, affichée à gauche de son nom ; celle du
  /// joueur 2, l'opposée, à droite du sien. Rien si null.
  final double? eloDelta1;

  @override
  Widget build(BuildContext context) {
    Text text(String value, {TextStyle? style, TextAlign? align}) => Text(
      value,
      style: style ?? this.style,
      textAlign: align,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

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
    final d = eloDelta1;
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Row(
            spacing: 4,
            children: [
              if (d != null) _EloDelta(d),
              Flexible(child: text(m.player1, style: style1)),
            ],
          ),
        ),
        SizedBox(
          width: 20,
          child: text('${m.score1}', style: style1, align: TextAlign.right),
        ),
        Text('–', style: style),
        SizedBox(width: 20, child: text('${m.score2}', style: style2)),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 4,
            children: [
              Flexible(
                child: text(m.player2, style: style2, align: TextAlign.right),
              ),
              if (d != null) _EloDelta(-d),
            ],
          ),
        ),
      ],
    );
  }
}

/// Titre de colonne cliquable, pour trier la liste. [arrow] : flèche vers le
/// haut (true) ou le bas (false) sur la colonne triée, rien sur l'autre.
class _SortHeader extends StatelessWidget {
  const _SortHeader(this.label, {required this.arrow, required this.onTap});

  final String label;
  final bool? arrow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = _text.copyWith(fontSize: 12, color: color);
    return InkWell(
      onTap: onTap,
      hoverColor: hoverColor,
      child: Padding(
        padding: _cellPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(label, style: style),
            if (arrow != null)
              Icon(
                arrow! ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

/// Pastilles des dernières parties, de la plus ancienne à la plus récente :
/// vertes pour les victoires, grises pour les nuls, rouges pour les défaites.
class _Form extends StatelessWidget {
  const _Form(this.outcomes);

  static const double dot = 8;

  final List<Outcome> outcomes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        for (final o in outcomes)
          Semantics(
            label: switch (o) {
              Outcome.win => 'Victoire',
              Outcome.draw => 'Nul',
              Outcome.loss => 'Défaite',
            },
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (o) {
                  Outcome.win => const Color(0xFF3FB96A),
                  Outcome.draw => const Color(0xFF8A8F94),
                  Outcome.loss => const Color(0xFFE5534B),
                },
              ),
            ),
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
class _LineList extends StatefulWidget {
  const _LineList(this.lines, {super.key, this.sortable = false, this.forms});

  final List<(String, String)> lines;

  /// Pastilles des dernières parties de chaque ligne (même ordre que
  /// [lines]), affichées avant la valeur.
  final List<List<Outcome>>? forms;

  /// Ajoute un en-tête pour trier par nom ou par valeur (numérique). Les
  /// lignes arrivent triées par valeur décroissante, le tri de départ.
  final bool sortable;

  @override
  State<_LineList> createState() => _LineListState();
}

class _LineListState extends State<_LineList> {
  _SortBy _sortBy = _SortBy.score;
  bool _ascending = false;

  /// Comme l'en-tête de la liste de gauche : la colonne déjà triée inverse
  /// le sens ; l'autre trie par nom de A à Z, ou par valeur décroissante.
  void _sort(_SortBy by) {
    setState(() {
      _ascending = by == _sortBy ? !_ascending : by == _SortBy.name;
      _sortBy = by;
    });
  }

  /// Positions des lignes dans l'ordre affiché.
  List<int> get _order {
    final lines = widget.lines;
    final order = [for (var i = 0; i < lines.length; i++) i];
    if (!widget.sortable) return order;
    final direction = _ascending ? 1 : -1;
    return order..sort((i, j) {
      final (a, b) = (lines[i], lines[j]);
      if (_sortBy == _SortBy.score) {
        final byValue = num.parse(a.$2).compareTo(num.parse(b.$2));
        if (byValue != 0) return direction * byValue;
        return a.$1.compareTo(b.$1);
      }
      return direction * a.$1.compareTo(b.$1);
    });
  }

  @override
  Widget build(BuildContext context) {
    const divider = BorderSide(color: dividerColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.sortable && widget.lines.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(border: Border(bottom: divider)),
            child: Row(
              children: [
                Expanded(
                  child: _SortHeader(
                    'Nom',
                    arrow: _sortBy == _SortBy.name ? _ascending : null,
                    onTap: () => _sort(_SortBy.name),
                  ),
                ),
                _SortHeader(
                  'Score',
                  arrow: _sortBy == _SortBy.score ? _ascending : null,
                  onTap: () => _sort(_SortBy.score),
                ),
              ],
            ),
          ),
        for (final i in _order)
          DecoratedBox(
            decoration: BoxDecoration(border: Border(bottom: divider)),
            child: Padding(
              padding: _cellPadding,
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      widget.lines[i].$1,
                      style: _text,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.forms case final forms?) ...[
                    _Form(forms[i]),
                    // Largeur fixe, comme dans la liste de gauche : les
                    // valeurs restent alignées.
                    SizedBox(
                      width: _scoreWidth,
                      child: Text(
                        widget.lines[i].$2,
                        style: _text,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ] else
                    Text(widget.lines[i].$2, style: _text),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Évolution d'un ELO : signée, à une décimale (virgule), en vert si elle
/// est positive, en rouge si elle est négative, en gris si elle est nulle.
class _EloDelta extends StatelessWidget {
  const _EloDelta(this.delta);

  final double delta;

  @override
  Widget build(BuildContext context) {
    final rounded = (delta * 10).round() / 10;
    final sign = rounded > 0 ? '+' : (rounded < 0 ? '−' : '±');
    final value = rounded.abs().toStringAsFixed(1).replaceAll('.', ',');
    return Text(
      '$sign$value',
      style: _text.copyWith(
        fontSize: 12,
        color: rounded > 0
            ? const Color(0xFF3FB96A)
            : rounded < 0
            ? const Color(0xFFE5534B)
            : const Color(0xFF8A8F94),
      ),
    );
  }
}

/// Liste de parties, au style de la liste de gauche, sous un petit titre.
/// Rien si la liste est vide.
/// Date au format jj/mm/aaaa, dans le fuseau de l'appareil.
String _formatDate(DateTime date) {
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Tri des parties du détail : par date (de la plus récente à la plus
/// ancienne, l'ordre de départ), par jeu ou par lieu.
enum _MatchSort { date, game, place }

class _MatchupList extends StatefulWidget {
  const _MatchupList(this.matchups, {super.key});

  /// Largeur des colonnes de la date et du jeu, à gauche, et de celle du
  /// lieu, à droite.
  static const double dateWidth = 76;
  static const double gameWidth = 120;
  static const double placeWidth = 80;

  /// Parties, de la plus récente à la plus ancienne.
  final List<MatchDetail> matchups;

  @override
  State<_MatchupList> createState() => _MatchupListState();
}

class _MatchupListState extends State<_MatchupList> {
  _MatchSort _sortBy = _MatchSort.date;
  bool _ascending = false;

  /// Un clic sur « Date » trie de la plus récente à la plus ancienne, sur
  /// « Jeu » ou « Lieu » de A à Z ; un second clic sur la même colonne
  /// inverse le sens.
  void _sort(_MatchSort by) {
    setState(() {
      _ascending = by == _sortBy ? !_ascending : by != _MatchSort.date;
      _sortBy = by;
    });
  }

  /// Positions des parties dans l'ordre affiché ; à égalité, de la plus
  /// récente à la plus ancienne.
  List<int> _order(List<MatchDetail> matchups) {
    final order = [for (var i = 0; i < matchups.length; i++) i];
    // Les parties arrivent de la plus récente à la plus ancienne.
    if (_sortBy == _MatchSort.date) {
      return _ascending ? order.reversed.toList() : order;
    }
    String key(MatchDetail m) =>
        _sortBy == _MatchSort.game ? m.game : (m.place ?? '');
    final direction = _ascending ? 1 : -1;
    return order..sort((i, j) {
      final byKey = key(matchups[i]).compareTo(key(matchups[j]));
      return byKey != 0 ? direction * byKey : i.compareTo(j);
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchups = widget.matchups;
    if (matchups.isEmpty) return const SizedBox.shrink();
    const dateWidth = _MatchupList.dateWidth;
    const gameWidth = _MatchupList.gameWidth;
    const placeWidth = _MatchupList.placeWidth;
    const divider = BorderSide(color: dividerColor);
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Un large espace au-dessus, pour la séparer de la liste précédente.
          padding: const EdgeInsets.fromLTRB(12, 32, 12, 4),
          child: Text(
            'Parties',
            style: _text.copyWith(fontSize: 12, color: labelColor),
          ),
        ),
        // En-tête : trier par date, par jeu ou par lieu. Chaque titre au-dessus
        // de sa colonne.
        DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: divider)),
          child: Row(
            children: [
              SizedBox(
                width: dateWidth + 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SortHeader(
                    'Date',
                    arrow: _sortBy == _MatchSort.date ? _ascending : null,
                    onTap: () => _sort(_MatchSort.date),
                  ),
                ),
              ),
              _SortHeader(
                'Jeu',
                arrow: _sortBy == _MatchSort.game ? _ascending : null,
                onTap: () => _sort(_MatchSort.game),
              ),
              const Spacer(),
              _SortHeader(
                'Lieu',
                arrow: _sortBy == _MatchSort.place ? _ascending : null,
                onTap: () => _sort(_MatchSort.place),
              ),
            ],
          ),
        ),
        // La date et le jeu à gauche du joueur 1, le lieu à droite du
        // joueur 2.
        for (final m in [for (final i in _order(matchups)) matchups[i]])
          DecoratedBox(
            decoration: BoxDecoration(border: Border(bottom: divider)),
            child: Padding(
              padding: _cellPadding,
              child: Row(
                spacing: 12,
                children: [
                  SizedBox(
                    width: dateWidth,
                    child: Text(
                      _formatDate(m.date),
                      style: _text.copyWith(color: labelColor),
                      softWrap: false,
                    ),
                  ),
                  SizedBox(
                    width: gameWidth,
                    child: Text(
                      m.game,
                      style: _text.copyWith(color: labelColor),
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: _MatchupLine(
                      m.matchup,
                      style: _text,
                      eloDelta1: m.eloDelta1,
                    ),
                  ),
                  SizedBox(
                    width: placeWidth,
                    child: Text(
                      m.place ?? '',
                      style: _text.copyWith(color: labelColor),
                      textAlign: TextAlign.right,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
