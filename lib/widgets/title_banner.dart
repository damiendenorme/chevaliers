import 'package:flutter/material.dart';

import 'row_list.dart';
import 'top_bar.dart';

/// Grande bannière verticale du site, en haut à gauche (dans la marge
/// laissée par les cartes) : « Les Chevaliers Occitans » dans la police
/// du site, sur le fond texturé des boutons activés (couleur de la page),
/// bas échancré comme les bannières des joueurs, avec le bourrelet des
/// cartes. Collée au bord du haut de l'écran : son bourrelet du haut est
/// caché au-dessus, comme accroché au bord.
class TitleBanner extends StatelessWidget {
  const TitleBanner({super.key});

  static const double width = 120;
  static const double height = 220;

  /// Profondeur de l'échancrure du bas.
  static const double notch = 24;

  @override
  Widget build(BuildContext context) {
    final accent = AccentStyle.of(context);
    return Transform.translate(
      offset: const Offset(0, -BevelEdge.width),
      child: CustomPaint(
        foregroundPainter: _BannerBevelPainter(accent.edge),
        child: ClipPath(
          clipper: const BannerClipper(notch),
          child: Container(
            width: width,
            height: height,
            decoration: accent.texture,
            child: Stack(
              children: [
                // Centrées en hauteur, chacune sur la moitié de la largeur
                // (sans se chevaucher) : la moitié droite de la croix
                // occitane, collée au bord gauche, et la moitié gauche du
                // lion, collée au bord droit.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _half(
                    const _Emblem(
                      'assets/croix-occitane.jpg',
                      size: width,
                      color: _emblemColor,
                      // Rouge sur fond blanc ou transparent.
                      alphaFrom: 1,
                    ),
                    right: true,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _half(
                    const _Emblem(
                      'assets/black-silhouette-of-a-rampant-lion-heraldic-symbol-vector.jpg',
                      size: width,
                      color: _emblemColor,
                      // Noir sur fond blanc, avec plus de marge : agrandi
                      // pour paraître de la taille de la croix.
                      alphaFrom: 0,
                      scale: 1.6,
                    ),
                    right: false,
                  ),
                ),
                // Par-dessus, le texte, centré (au-dessus de l'échancrure).
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: notch,
                      left: 10,
                      right: 10,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Les\nChevaliers\nOccitans',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.1,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Moitié droite ([right]) ou gauche de [child], l'autre moitié coupée.
  static Widget _half(Widget child, {required bool right}) => ClipRect(
    child: Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      widthFactor: 0.5,
      child: child,
    ),
  );
}

/// Couleur des emblèmes : blanc transparent.
const _emblemColor = Color(0x40FFFFFF);

/// Emblème de la bannière : une image dessinée d'une seule [color], son
/// fond blanc rendu transparent. L'opacité vient du canal [alphaFrom]
/// de l'image (0 : rouge, 1 : vert), qui vaut 1 sur le blanc et 0 sur le
/// motif : opacité = opacité de l'image − ce canal.
class _Emblem extends StatelessWidget {
  const _Emblem(
    this.asset, {
    required this.size,
    required this.color,
    required this.alphaFrom,
    this.scale = 1,
  });

  /// Côté du carré de l'image.
  final double size;

  final String asset;
  final Color color;
  final int alphaFrom;

  /// Agrandissement du dessin, sans changer la place prise.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix([
        0, 0, 0, 0, color.r * 255, //
        0, 0, 0, 0, color.g * 255, //
        0, 0, 0, 0, color.b * 255, //
        // Opacité multipliée par celle de [color].
        if (alphaFrom == 0) ...[
          -color.a,
          0,
          0,
          color.a,
          0,
        ] else ...[
          0,
          -color.a,
          0,
          color.a,
          0,
        ],
      ]),
      child: Transform.scale(
        scale: scale,
        child: Image.asset(asset, width: size, height: size),
      ),
    );
  }
}

/// Bourrelet des cartes (voir [BevelEdge]) le long de la forme de la
/// bannière, à l'intérieur : un centre clair entre deux bords sombres.
class _BannerBevelPainter extends CustomPainter {
  const _BannerBevelPainter(this.edge);

  /// Couleurs du bourrelet (voir [AccentStyle.edge]).
  final (Color, Color, Color) edge;

  @override
  void paint(Canvas canvas, Size size) {
    final path = bannerPath(size, TitleBanner.notch);
    canvas.save();
    canvas.clipPath(path);
    // Traits centrés sur le contour, découpés à l'intérieur : du plus large
    // (bord intérieur) au plus fin (bord extérieur).
    for (final (depth, color) in [
      (BevelEdge.width, edge.$3),
      (BevelEdge.width - 1, edge.$2),
      (1.0, edge.$1),
    ]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = depth * 2
          ..strokeJoin = StrokeJoin.miter
          ..color = color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BannerBevelPainter old) => old.edge != edge;
}
