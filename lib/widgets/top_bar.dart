import 'package:flutter/material.dart';

/// Couleur des zones posées sur le fond (barre, boutons, cartes) : brun
/// sombre de cuir ancien.
const topBarColor = Color(0xFF1E1915);

/// Liseré des cartes et de la barre : bronze patiné, touche médiévale.
const edgeColor = Color(0xFF5A4630);

/// Séparateurs entre les éléments des listes : gris, discret sur le fond
/// sombre des cartes.
const dividerColor = Color(0xFF3A3532);

/// Couleur des éléments actifs : bleu, avec le texte en blanc.
const accentColor = Color(0xFF2F6FDB);

/// Couleur des survols : bleu sombre, pour garder le texte clair lisible.
const hoverColor = Color(0xFF26364F);

/// Légère ombre portée des boutons et des cartes.
const lightShadow = [
  BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
];

/// Bordure en bourrelet bronze, en relief, identique sur tout le tour (pas
/// de lumière projetée) : un centre clair entre deux bords sombres, comme un
/// jonc arrondi. Dessinée par-dessus [child], sans le décaler.
class BevelEdge extends StatelessWidget {
  const BevelEdge({super.key, required this.child, this.radius = 8});

  /// Épaisseur totale du bourrelet.
  static const double width = 4;

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(foregroundPainter: _BevelPainter(radius), child: child);
  }
}

class _BevelPainter extends CustomPainter {
  const _BevelPainter(this.radius);

  final double radius;

  /// Du bord extérieur vers l'intérieur : (épaisseur, couleur).
  static const _rings = [
    (1.0, Color(0xFF3A2A18)),
    (2.0, Color(0xFFB8955F)),
    (1.0, Color(0xFF4A3822)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var inset = 0.0;
    for (final (width, color) in _rings) {
      final middle = inset + width / 2;
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
      inset += width;
    }
  }

  @override
  bool shouldRepaint(_BevelPainter old) => old.radius != radius;
}
