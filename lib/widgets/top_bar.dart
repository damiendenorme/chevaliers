import 'package:flutter/material.dart';

/// Couleur des zones posées sur le fond (barre, boutons, cartes) : brun
/// sombre de cuir ancien.
const topBarColor = Color(0xFF1E1915);

/// Liseré des cartes et de la barre : bronze patiné, touche médiévale.
const edgeColor = Color(0xFF5A4630);

/// Séparateurs entre les éléments des listes : gris, discret sur le fond
/// sombre des cartes.
const dividerColor = Color(0xFF3A3532);

/// Couleur des éléments actifs : marron sombre, comme le bois de l'image de
/// fond, avec le texte en blanc.
const accentColor = Color(0xFF5C3A1E);

/// Couleur des survols : brun, dans les tons de l'accent mais plus discret,
/// pour garder le texte clair lisible.
const hoverColor = Color(0xFF3D2A1A);

/// Légère ombre portée des boutons et des cartes.
const lightShadow = [
  BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
];

/// Surface des cartes : l'image Carte assombrie, à coins arrondis, bourrelet
/// bronze en relief et légère ombre ; son contenu (ligne active, survol) est
/// découpé avec.
class CardSurface extends StatelessWidget {
  const CardSurface(this.child, {super.key, this.inset = true});

  final Widget child;

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
                fit: BoxFit.fill,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.72),
                  BlendMode.srcATop,
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Marque-page accroché au bord gauche de l'écran, au design des cartes,
/// avec son texte vertical (de bas en haut) : son côté gauche dépasse de
/// l'écran, seuls son bout et ses coins droits, arrondis, sont visibles.
/// Actif, il est coloré comme la ligne choisie d'une liste, dépasse un peu
/// plus et paraît en creux ; non choisi, il paraît bombé.
class Bookmark extends StatelessWidget {
  const Bookmark({
    super.key,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  /// Largeur visible.
  static const double width = 40;

  /// Partie cachée à gauche de l'écran (rayon des coins et bourrelet).
  static const double _hidden = 12;

  /// Le marque-page actif dépasse de ce supplément.
  static const double _activeExtra = 8;

  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final shift = active ? 0.0 : -_activeExtra;
    const hiddenPart = _hidden + _activeExtra;
    const total = width + hiddenPart;
    return Transform.translate(
      offset: Offset(-_hidden + shift, 0),
      child: SizedBox(
        width: total,
        child: Semantics(
          button: true,
          selected: active,
          // Non choisi : sans effet de creux, et bombé (un reflet le long du
          // marque-page, plus sombre vers ses bords visibles).
          child: CardSurface(
            inset: active,
            Material(
              color: active
                  ? accentColor.withValues(alpha: 0.85)
                  : Colors.transparent,
              child: Ink(
                decoration: active
                    ? null
                    : const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x40000000),
                            Color(0x2EFFFFFF),
                            Color(0x00FFFFFF),
                            Color(0x66000000),
                          ],
                          stops: [hiddenPart / total, 0.55, 0.75, 1],
                        ),
                      ),
                child: InkWell(
                  onTap: onPressed,
                  hoverColor: hoverColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(hiddenPart, 20, 0, 20),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: active ? Colors.white : null,
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
      foregroundPainter: _BevelPainter(radius, inset: inset),
      child: child,
    );
  }
}

class _BevelPainter extends CustomPainter {
  const _BevelPainter(this.radius, {required this.inset});

  final double radius;
  final bool inset;

  /// Du bord extérieur vers l'intérieur : (épaisseur, couleur).
  static const _rings = [
    (1.0, Color(0xFF3A2A18)),
    (2.0, Color(0xFFB8955F)),
    (1.0, Color(0xFF4A3822)),
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
      old.radius != radius || old.inset != inset;
}
