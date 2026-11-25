import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Couleur des zones posées sur le fond (barre, boutons, cartes) : brun
/// sombre de cuir ancien.
const topBarColor = Color(0xFF1E1915);

/// Séparateurs entre les éléments des listes : gris, discret sur le fond
/// sombre des cartes.
const dividerColor = Color(0xFF3A3532);

/// Couleur d'accentuation d'une page : le fond texturé des éléments actifs
/// (la pierre de l'image Carte teintée de [color], ses veines restant
/// sombres), la bordure de l'élément choisi d'une liste ou d'un menu, le
/// survol et le bourrelet des cartes.
class AccentStyle {
  const AccentStyle(
    this.color,
    this.border, {
    required this.hover,
    required this.edge,
  });

  /// Couleur des éléments actifs, avec le texte en blanc.
  final Color color;

  /// Bordure de l'élément choisi : un gris clair teinté de [color].
  final Color border;

  /// Survols : dans les tons de [color], plus discret, pour garder le texte
  /// clair lisible.
  final Color hover;

  /// Bourrelet des cartes, de l'extérieur vers l'intérieur : bord sombre,
  /// centre clair, bord sombre.
  final (Color, Color, Color) edge;

  /// Wargame : bronze doré, qui rappelle le bourrelet des cartes.
  static const wargame = AccentStyle(
    Color(0xFF9E7C38),
    Color(0xFFAA9262),
    hover: Color(0xFF45301E),
    edge: (Color(0xFF3A2A18), Color(0xFFC8A66C), Color(0xFF4A3822)),
  );

  /// RPG : bronze, plus cuivré et plus sombre que l'or du Wargame.
  static const rpg = AccentStyle(
    Color(0xFF6C4321),
    Color(0xFF84654F),
    hover: Color(0xFF2C1D14),
    edge: (Color(0xFF26170D), Color(0xFF946233), Color(0xFF342112)),
  );

  BoxDecoration get texture => BoxDecoration(
    color: color,
    image: DecorationImage(
      image: const AssetImage('assets/Carte.jpg'),
      fit: BoxFit.cover,
      colorFilter: ColorFilter.mode(color, BlendMode.multiply),
    ),
  );

  /// [texture] plus plate : la pierre à peine visible sur la couleur unie.
  BoxDecoration get flatTexture => BoxDecoration(
    color: color,
    image: DecorationImage(
      image: const AssetImage('assets/Carte.jpg'),
      fit: BoxFit.cover,
      opacity: 0.3,
      colorFilter: ColorFilter.mode(color, BlendMode.multiply),
    ),
  );

  /// Accentuation de la page qui contient [context] (Wargame par défaut).
  static AccentStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccentScope>()?.style ??
      wargame;

  @override
  bool operator ==(Object other) =>
      other is AccentStyle &&
      other.color == color &&
      other.border == border &&
      other.hover == hover &&
      other.edge == edge;

  @override
  int get hashCode => Object.hash(color, border, hover, edge);
}

/// Donne l'accentuation [style] à tout ce qu'il contient (une page).
class AccentScope extends InheritedWidget {
  const AccentScope({super.key, required this.style, required super.child});

  final AccentStyle style;

  @override
  bool updateShouldNotify(AccentScope old) => old.style != style;
}

/// Légère ombre portée des boutons et des cartes.
const lightShadow = [
  BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
];

/// Surface des cartes : l'image Carte assombrie, à coins arrondis, bourrelet
/// bronze en relief et légère ombre ; son contenu (ligne active, survol),
/// à [padding] des bords, est découpé avec.
class CardSurface extends StatelessWidget {
  const CardSurface(
    this.child, {
    super.key,
    this.inset = true,
    this.fit = BoxFit.fill,
    this.padding = const EdgeInsets.all(gutter),
  });

  /// Écart entre les bords de la carte et son contenu.
  static const double gutter = 5;

  final Widget child;

  /// Écart entre les bords et le contenu : [gutter] tout autour par défaut.
  /// Une carte dont le contenu défile le réduit, et reporte l'écart dans son
  /// défilement : sa barre reste collée au bord.
  final EdgeInsets padding;

  /// Cadrage de l'image : étirée par défaut, pour que son cadre suive les
  /// bords ; [BoxFit.cover] pour la garder dans ses proportions.
  final BoxFit fit;

  /// Ombre portée interne en haut (effet de creux). Sans elle, la carte ne
  /// paraît pas enfoncée.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    // L'ombre est posée hors du découpage, pour ne pas être coupée ; le
    // bourrelet bronze par-dessus le contenu.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: lightShadow),
      position: DecorationPosition.background,
      child: BevelEdge(
        inset: inset,
        child: ClipRRect(
          borderRadius: radius,
          // Fond : l'image Carte, assombrie pour garder le texte clair
          // lisible, étirée pour que son cadre suive les bords de la carte.
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: topBarColor,
              image: DecorationImage(
                image: const AssetImage('assets/Carte.jpg'),
                fit: fit,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.72),
                  BlendMode.srcATop,
                ),
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Survol bombé : sous [child], le fond brun du survol de la page, à peine
/// bombé (l'inverse de l'effet de creux des éléments choisis) : un peu plus
/// clair en haut, un peu plus sombre en bas, avec une touche de la texture
/// des cartes. Rien si [enabled] est faux (élément choisi).
class HoverBulge extends StatefulWidget {
  const HoverBulge({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<HoverBulge> createState() => _HoverBulgeState();
}

class _HoverBulgeState extends State<HoverBulge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hover = AccentStyle.of(context).hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        decoration: _hovered && widget.enabled
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(hover, Colors.white, 0.06)!,
                    hover,
                    hover,
                    Color.lerp(hover, Colors.black, 0.18)!,
                  ],
                  stops: const [0, 0.4, 0.7, 1],
                ),
                // Une touche de la texture de pierre des cartes.
                image: const DecorationImage(
                  image: AssetImage('assets/Carte.jpg'),
                  fit: BoxFit.cover,
                  opacity: 0.12,
                ),
              )
            : const BoxDecoration(),
        child: widget.child,
      ),
    );
  }
}

/// Plaque au design de l'encoche du haut (fond sombre, bourrelet bronze,
/// ombre), posée librement : ses quatre coins sont arrondis.
class Plate extends StatelessWidget {
  const Plate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BevelEdge(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: topBarColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: lightShadow,
        ),
        child: child,
      ),
    );
  }
}

/// Marque-page accroché au bord gauche de l'écran, au design des cartes,
/// avec son nom et son icône sur une ligne : verticale (de bas en haut) s'il
/// est inactif, horizontale s'il est actif ; tous de même hauteur : son côté gauche dépasse de
/// l'écran, seuls son bout et ses coins droits, arrondis, sont visibles.
/// Actif, il est coloré comme la ligne choisie d'une liste, plus large et en
/// creux ; inactif, il est gris et bombé.
class Bookmark extends StatefulWidget {
  const Bookmark({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    this.active = false,
    this.accent = AccentStyle.wargame,
  });

  /// Couleur d'accentuation, quand il est actif : celle de sa page.
  final AccentStyle accent;

  /// Chemin de son icône (SVG) dans les assets.
  final String icon;

  /// Largeur visible d'un marque-page inactif : son nom et son icône sur
  /// une ligne tournée à la verticale.
  static const double inactiveWidth = 40;

  /// Largeur visible du marque-page actif : son nom à l'horizontale et son
  /// icône à droite.
  static const double activeWidth = 130;

  /// Hauteur, la même pour tous les marque-pages.
  static const double height = 150;

  /// Partie cachée à gauche de l'écran (rayon des coins et bourrelet).
  static const double _hidden = 12;

  /// Durée de l'animation : le marque-page qu'on tire ou qu'on repousse.
  static const duration = Duration(milliseconds: 320);

  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  State<Bookmark> createState() => _BookmarkState();
}

class _BookmarkState extends State<Bookmark> {
  /// Survol désactivé : le marque-page actif, une fois tiré, n'a plus rien
  /// à proposer au clic.
  late bool _hoverOff = widget.active;
  Timer? _timer;

  @override
  void didUpdateWidget(Bookmark old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    _timer?.cancel();
    if (widget.active) {
      // Le survol disparaît à la fin de l'animation.
      _timer = Timer(Bookmark.duration, () {
        if (mounted) setState(() => _hoverOff = true);
      });
    } else {
      _hoverOff = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final accent = widget.accent;
    final visible = active ? Bookmark.activeWidth : Bookmark.inactiveWidth;
    final total = visible + Bookmark._hidden;
    // Actif ou replié : bourrelet, fond et survol aux couleurs de sa page.
    const color = Colors.white;
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 14, color: color)),
        SvgPicture.asset(
          widget.icon,
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ],
    );
    return AccentScope(
      style: accent,
      child: Transform.translate(
        offset: const Offset(-Bookmark._hidden, 0),
        // Tiré (actif) : il s'élargit, avec un léger dépassement comme un
        // geste de la main ; repoussé : il se rétracte.
        child: AnimatedContainer(
          duration: Bookmark.duration,
          curve: active ? Curves.easeOutBack : Curves.easeInOutCubic,
          width: total,
          height: Bookmark.height,
          child: Semantics(
            button: true,
            selected: active,
            // Non choisi : sans effet de creux, et bombé (un reflet le long du
            // marque-page, plus sombre vers ses bords visibles), sur le fond
            // texturé de sa couleur.
            child: CardSurface(
              inset: active,
              Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: accent.texture,
                  child: Ink(
                    decoration: active
                        ? const BoxDecoration()
                        : BoxDecoration(
                            gradient: LinearGradient(
                              colors: const [
                                Color(0x40000000),
                                Color(0x2EFFFFFF),
                                Color(0x00FFFFFF),
                                Color(0x66000000),
                              ],
                              stops: [Bookmark._hidden / total, 0.55, 0.75, 1],
                            ),
                          ),
                    // Survol coupé une fois actif et l'animation terminée : son
                    // fond reste visible. La clé recrée l'encre à ce moment-là,
                    // pour effacer le survol déjà affiché.
                    child: InkWell(
                      key: ValueKey(_hoverOff),
                      onTap: widget.onPressed,
                      hoverColor: _hoverOff ? Colors.transparent : accent.hover,
                      // Son nom puis son icône sur une ligne, centrée dans la
                      // partie visible : à l'horizontale s'il est actif, tournée
                      // à la verticale (lue de bas en haut) sinon.
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Bookmark._hidden,
                          16,
                          0,
                          16,
                        ),
                        // La ligne tourne d'un quart de tour pendant
                        // l'animation : de la verticale à l'horizontale quand
                        // on le tire, et inversement. Elle garde sa taille,
                        // le marque-page la découpe si besoin.
                        child: Center(
                          child: OverflowBox(
                            maxWidth: double.infinity,
                            maxHeight: double.infinity,
                            child: AnimatedRotation(
                              turns: active ? 0 : -0.25,
                              duration: Bookmark.duration,
                              curve: active
                                  ? Curves.easeOutBack
                                  : Curves.easeInOutCubic,
                              child: line,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encoche suspendue au bord du haut de l'écran, au style de la barre :
/// une rangée d'informations (icône + nombre). Tant qu'un nombre est
/// inconnu, un tiret.
///
/// Son haut dépasse de l'écran : seuls ses côtés et son bas, arrondis,
/// sont visibles, comme accrochés au bord.
class TopNotch extends StatelessWidget {
  const TopNotch({super.key, required this.items});

  /// Icône, libellé (pour les lecteurs d'écran) et nombre de chaque
  /// information, de gauche à droite.
  final List<(IconData, String, int?)> items;

  /// Partie cachée au-dessus de l'écran (rayon des coins et bourrelet).
  static const double _hidden = 12;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -_hidden),
      child: BevelEdge(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, _hidden + 6, 16, 6),
          decoration: BoxDecoration(
            color: topBarColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: lightShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              for (final (icon, label, value) in items)
                Semantics(
                  label: '$label : ${value ?? 'inconnu'}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Icon(icon, size: 16),
                      Text(
                        value?.toString() ?? '–',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bordure en bourrelet bronze, en relief, identique sur tout le tour (pas
/// de lumière projetée) : un centre clair entre deux bords sombres, comme un
/// jonc arrondi, avec une ombre portée interne en haut. Dessinée par-dessus
/// [child], sans le décaler.
class BevelEdge extends StatelessWidget {
  const BevelEdge({
    super.key,
    required this.child,
    this.radius = 8,
    this.inset = true,
  });

  /// Avec l'ombre portée interne en haut.
  final bool inset;

  /// Épaisseur totale du bourrelet.
  static const double width = 4;

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _BevelPainter(
        radius,
        inset: inset,
        edge: AccentStyle.of(context).edge,
      ),
      child: child,
    );
  }
}

class _BevelPainter extends CustomPainter {
  const _BevelPainter(this.radius, {required this.inset, required this.edge});

  final double radius;

  /// Couleurs du bourrelet (voir [AccentStyle.edge]).
  final (Color, Color, Color) edge;
  final bool inset;

  /// Du bord extérieur vers l'intérieur : (épaisseur, couleur).
  List<(double, Color)> get _rings => [
    (1.0, edge.$1),
    (2.0, edge.$2),
    (1.0, edge.$3),
  ];

  /// Hauteur de l'ombre portée interne, en haut.
  static const _shadowHeight = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Ombre portée interne en haut : du noir qui s'efface vers le bas, sous
    // le bourrelet, dans les coins arrondis.
    if (inset) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
      final shadow = Rect.fromLTWH(0, 0, size.width, _shadowHeight);
      canvas.drawRect(
        shadow,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99000000), Color(0x00000000)],
          ).createShader(shadow),
      );
      canvas.restore();
    }

    var edge = 0.0;
    for (final (width, color) in _rings) {
      final middle = edge + width / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(middle),
          Radius.circular((radius - middle).clamp(0, radius)),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );
      edge += width;
    }
  }

  @override
  bool shouldRepaint(_BevelPainter old) =>
      old.radius != radius || old.inset != inset || old.edge != edge;
}
