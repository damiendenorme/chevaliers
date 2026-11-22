import 'package:flutter/material.dart';

import 'row_list.dart';
import 'top_bar.dart';

/// Grande bannière verticale du site, en haut à gauche (dans la marge
/// laissée par les cartes) : « Les Chevaliers » dans la police
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
            padding: const EdgeInsets.only(bottom: notch, left: 10, right: 10),
            alignment: Alignment.center,
            decoration: accent.texture,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Les\nChevaliers',
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
