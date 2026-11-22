import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        // Carte étroite : son image garde ses proportions, sans être étirée.
        SizedBox(
          width: RowList.listWidth,
          child: CardSurface(master, fit: BoxFit.cover),
        ),
        Expanded(child: CardSurface(detail ?? const SizedBox.shrink())),
      ],
    );
  }
}

const _text = TextStyle(fontSize: 14);

/// Ombre portée interne en haut d'un élément choisi de la liste : il paraît
/// légèrement en creux.
const _insetShadow = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x4D000000), Color(0x00000000)],
  stops: [0, 0.3],
);

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

  /// Valeur de tri de chaque ligne, à côté du nom : le score (joueurs), le
  /// nombre de joueurs (jeux) ou la date (événements).
  Comparable<Object>? _value(RowTable table, int i) =>
      table.globalScores != null
      ? table.globalScore(i)
      : table.badges != null
      ? table.badge(i)
      : table.date(i);

  /// Titre de la colonne de cette valeur, ou null : liste sans en-tête.
  String? get _valueLabel {
    final table = widget.table;
    if (table.globalScores != null) return 'Score';
    if (table.badges != null) return 'Joueurs';
    if (table.dates != null) return 'Date';
    return null;
  }

  bool get _sortable => _valueLabel != null;

  /// Tri de la liste au départ : les joueurs par score décroissant, les
  /// jeux par nom.
  late _SortBy _sortBy = widget.table.globalScores != null
      ? _SortBy.score
      : _SortBy.name;
  late bool _ascending = _sortBy == _SortBy.name;

  /// Cliquer sur la colonne déjà triée inverse le sens ; sur l'autre, trie
  /// par nom de A à Z, ou par valeur décroissante.
  void _sort(_SortBy by) {
    setState(() {
      _ascending = by == _sortBy ? !_ascending : by == _SortBy.name;
      _sortBy = by;
    });
  }

  /// Positions des lignes dans l'ordre affiché. Sans valeur, toujours en
  /// dernier.
  List<int> _order(RowTable table) {
    final order = [for (var i = 0; i < table.rows.length; i++) i];
    if (!_sortable) return order;
    final direction = _ascending ? 1 : -1;
    return order..sort((a, b) {
      if (_sortBy == _SortBy.score) {
        final (sa, sb) = (_value(table, a), _value(table, b));
        if (sa == null || sb == null) {
          if (sa != sb) return sa == null ? 1 : -1;
        } else if (sa != sb) {
          return direction * sa.compareTo(sb as Object);
        }
      }
      return (_sortBy == _SortBy.name ? direction : 1) *
          compareNames(table.title(a), table.title(b));
    });
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    const divider = BorderSide(color: dividerColor);

    final list = SingleChildScrollView(
      // Sans en-tête, le premier élément est baissé de l'épaisseur du
      // bourrelet, comme l'en-tête : il paraît aussi haut que les autres.
      padding: EdgeInsets.only(top: _sortable ? 0 : BevelEdge.width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in _order(table))
            Material(
              // Transparente : le fond de la carte reste visible. Choisie :
              // le fond texturé doré.
              color: Colors.transparent,
              // Choisie : tout autour, une bordure grise un peu plus claire.
              shape: i == _selected
                  ? Border.all(color: AccentStyle.of(context).border)
                  : const Border(bottom: divider),
              child: Ink(
                decoration: i == _selected
                    ? AccentStyle.of(context).texture
                    : null,
                child: InkWell(
                  onTap: () => setState(() => _selected = i),
                  hoverColor: AccentStyle.of(context).hover,
                  // Choisie : en creux, comme le libellé actif de la barre
                  // (ombre portée interne en haut).
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: i == _selected
                        ? const BoxDecoration(gradient: _insetShadow)
                        : const BoxDecoration(),
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
              ),
            ),
        ],
      ),
    );

    return _Cards(
      // Avec des scores : un en-tête fixe au-dessus de la liste, pour la
      // trier par nom ou par score.
      master: !_sortable
          ? list
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Baissé de l'épaisseur du bourrelet, avec la hauteur de
                // ligne de la liste : il paraît aussi haut que ses éléments.
                DecoratedBox(
                  decoration: BoxDecoration(border: Border(bottom: divider)),
                  child: Padding(
                    padding: const EdgeInsets.only(top: BevelEdge.width),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SortHeader(
                            'Nom',
                            arrow: _sortBy == _SortBy.name ? _ascending : null,
                            onTap: () => _sort(_SortBy.name),
                            rowHeight: true,
                          ),
                        ),
                        _SortHeader(
                          _valueLabel!,
                          arrow: _sortBy == _SortBy.score ? _ascending : null,
                          onTap: () => _sort(_SortBy.score),
                          rowHeight: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: list),
              ],
            ),
      detail: _selected == null
          ? null
          // La zone de photos remplit le bas de la carte (son message, s'il
          // n'y a pas de photo, y est centré).
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Banner(table.banner(_selected!)),
                      // Une partie : en grand, à la place de ses colonnes.
                      if (table.matchDetail(_selected!) case final m?)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: _MatchDetailLine(m, stacked: true),
                        )
                      else
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
                        showGame: table.matchListShowsGame,
                      ),
                    ],
                  ),
                ),
                if (table.photosOf(_selected!) case final urls?)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _PhotoZone(urls),
                  ),
              ],
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
    final date = table.dates == null ? null : table.date(index);
    if (m == null && table.dates != null) {
      return Row(
        spacing: 8,
        children: [
          Expanded(child: text(table.title(index))),
          text(date == null ? '—' : formatMonth(date)),
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
  const _MatchupLine(
    this.m, {
    required this.style,
    this.eloDelta1,
    this.hugScores = false,
    this.scoreSize,
    this.form1,
    this.form2,
  });

  /// Pastilles des dernières parties de chaque joueur, collées du côté
  /// extérieur de son nom (et de son évolution d'ELO). Rien si null.
  final List<Outcome>? form1;
  final List<Outcome>? form2;

  final Matchup m;
  final TextStyle style;

  /// Chaque nom collé à son score, au lieu d'être aux extrémités.
  final bool hugScores;

  /// Taille des scores (et du tiret), si elle diffère de celle de [style].
  final double? scoreSize;

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
    final size = scoreSize ?? style.fontSize ?? 14;
    TextStyle scored(TextStyle s) => s.copyWith(fontSize: size);
    // Largeur d'un score (2 chiffres), proportionnelle à sa taille.
    final scoreWidth = 20 * size / 14;
    return Row(
      // Noms collés aux scores : un peu plus d'écart.
      spacing: hugScores ? 16 : 8,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: hugScores
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            spacing: 4,
            children: [
              // Pastilles un peu à l'écart (12px avec l'espacement).
              if (form1 case final f?)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Form(f),
                ),
              if (d != null) _EloDelta(d),
              Flexible(child: text(m.player1, style: style1)),
            ],
          ),
        ),
        SizedBox(
          width: scoreWidth,
          child: text(
            '${m.score1}',
            style: scored(style1),
            align: TextAlign.right,
          ),
        ),
        Text('–', style: scored(style)),
        SizedBox(
          width: scoreWidth,
          child: text('${m.score2}', style: scored(style2)),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: hugScores
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            spacing: 4,
            children: [
              Flexible(
                child: text(m.player2, style: style2, align: TextAlign.right),
              ),
              if (d != null) _EloDelta(-d),
              if (form2 case final f?)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _Form(f),
                ),
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
  const _SortHeader(
    this.label, {
    required this.arrow,
    required this.onTap,
    this.rowHeight = false,
  });

  final String label;
  final bool? arrow;
  final VoidCallback onTap;

  /// Même hauteur de ligne que les éléments de la liste (texte de 14px),
  /// malgré son texte plus petit.
  final bool rowHeight;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = _text.copyWith(fontSize: 12, color: color);
    return InkWell(
      onTap: onTap,
      hoverColor: AccentStyle.of(context).hover,
      child: Padding(
        padding: _cellPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(
              label,
              style: style,
              strutStyle: rowHeight
                  ? const StrutStyle(fontSize: 14, forceStrutHeight: true)
                  : null,
            ),
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

/// Bannière en haut du détail : l'image (asset en .jpg, .jpeg ou .png) de la
/// ligne sur toute la largeur, en fondu vers le transparent en bas. Sans fichier, un bandeau
/// vide de même taille.
class _Banner extends StatelessWidget {
  const _Banner(this.base);

  static const double height = 160;

  /// Chemin de l'image sans extension (voir [bannerAsset]).
  final String? base;

  /// Liste des assets de l'app, chargée une seule fois.
  static final Future<List<String>> _assets = AssetManifest.loadFromAssetBundle(
    rootBundle,
  ).then((m) => m.listAssets());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _assets,
      builder: (context, snapshot) {
        final assets = snapshot.data;
        final asset = base == null || assets == null
            ? null
            : resolveImageAsset(base!, assets);
        return _faded(context, asset);
      },
    );
  }

  Widget _faded(BuildContext context, String? asset) {
    final empty = ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    // Fondu vers le transparent en allant vers le bas : la bannière se fond
    // dans le fond de la carte.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.transparent],
      ).createShader(bounds),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: asset == null
            ? empty
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => empty,
              ),
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
        return compareNames(a.$1, b.$1);
      }
      return direction * compareNames(a.$1, b.$1);
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

/// Zone de photos : une grille de vignettes carrées ; un clic ouvre la photo
/// en grand. Sans photo, un message centré dans la zone.
class _PhotoZone extends StatelessWidget {
  const _PhotoZone(this.urls);

  static const double thumbnail = 120;

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    if (urls.isEmpty) {
      return Center(
        child: Text('Aucune photo.', style: _text.copyWith(color: labelColor)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in urls)
                _Thumbnail(
                  url,
                  size: thumbnail,
                  onTap: () => _open(context, url),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Photo en grand, par-dessus l'écran ; un clic à côté la ferme.
  void _open(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          child: Image.network(url, errorBuilder: (_, _, _) => const _Broken()),
        ),
      ),
    );
  }
}

/// Vignette carrée d'une photo, recadrée, à coins arrondis.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail(this.url, {required this.size, required this.onTap});

  final String url;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink.image(
          image: NetworkImage(url),
          width: size,
          height: size,
          fit: BoxFit.cover,
          onImageError: (_, _) {},
        ),
      ),
    );
  }
}

/// À la place d'une photo qui ne se charge pas.
class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 200,
      child: Icon(Icons.broken_image_outlined),
    );
  }
}

/// Liste de parties, au style de la liste de gauche, sous un petit titre.
/// Rien si la liste est vide.
/// Tri des parties du détail : par date (de la plus récente à la plus
/// ancienne, l'ordre de départ), par jeu ou par lieu.
enum _MatchSort { date, game, place }

class _MatchupList extends StatefulWidget {
  const _MatchupList(this.matchups, {super.key, this.showGame = true});

  /// Affiche la colonne du jeu (inutile quand toutes les parties sont du
  /// même jeu).
  final bool showGame;

  /// Largeur des colonnes de la date et du jeu, à gauche, et de celle du
  /// lieu, à droite.
  static const double dateWidth = 72;
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
      final byKey = compareNames(key(matchups[i]), key(matchups[j]));
      return byKey != 0 ? direction * byKey : i.compareTo(j);
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchups = widget.matchups;
    if (matchups.isEmpty) return const SizedBox.shrink();
    const dateWidth = _MatchupList.dateWidth;
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
              // Au moins la largeur de la colonne : « Jeu » au-dessus des jeux.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: dateWidth + 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: _SortHeader(
                    'Date',
                    arrow: _sortBy == _MatchSort.date ? _ascending : null,
                    onTap: () => _sort(_MatchSort.date),
                  ),
                ),
              ),
              if (widget.showGame)
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
              child: _MatchDetailLine(m, showGame: widget.showGame),
            ),
          ),
      ],
    );
  }
}

/// Une partie sur une ligne : la date et le jeu, puis la partie avec
/// l'évolution du ELO de chaque joueur, et le lieu à droite.
///
/// Dans une liste, la date, le jeu et le lieu ont des largeurs fixes : ils
/// restent alignés d'une ligne à l'autre. Seule ([stacked], détail d'une
/// partie), la date, le jeu et le lieu passent l'un sous l'autre au-dessus :
/// la partie a toute la largeur.
class _MatchDetailLine extends StatelessWidget {
  const _MatchDetailLine(this.m, {this.stacked = false, this.showGame = true});

  final MatchDetail m;
  final bool stacked;

  /// Affiche le jeu (dans une liste où toutes les parties sont du même jeu,
  /// non).
  final bool showGame;

  @override
  Widget build(BuildContext context) {
    final fixed = !stacked;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    const style = _text;
    final label = style.copyWith(color: labelColor);
    Widget column(String text, double width, {TextAlign? align}) {
      final child = Text(
        text,
        style: label,
        textAlign: align,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      );
      return fixed ? SizedBox(width: width, child: child) : child;
    }

    // Seule, la partie colle chaque nom à son score, en double taille.
    final matchup = _MatchupLine(
      m.matchup,
      style: style,
      eloDelta1: m.eloDelta1,
      hugScores: stacked,
      scoreSize: stacked ? 28 : null,
      form1: stacked ? m.form1 : null,
      form2: stacked ? m.form2 : null,
    );
    if (!fixed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          // Un peu plus bas sous la bannière.
          const SizedBox(height: 20),
          // La date, le jeu et le lieu l'un sous l'autre, centrés et plus
          // petits, puis la partie.
          for (final info in [formatDate(m.date), m.game, ?m.place])
            Text(
              info,
              style: label.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          // 36px entre le lieu et le score (avec l'espacement de la colonne).
          const SizedBox(height: 28),
          matchup,
        ],
      );
    }
    return Row(
      spacing: 12,
      children: [
        column(formatDate(m.date), _MatchupList.dateWidth),
        if (showGame) column(m.game, _MatchupList.gameWidth),
        Expanded(child: matchup),
        column(m.place ?? '', _MatchupList.placeWidth, align: TextAlign.right),
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
