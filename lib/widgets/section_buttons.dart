import 'package:flutter/material.dart';

import 'top_bar.dart';

/// Rangée horizontale de boutons texte, un par libellé.
class SectionButtons extends StatelessWidget {
  const SectionButtons({
    super.key,
    required this.buttons,
    required this.onPressed,
    this.active,
  });

  /// Libellé de chaque bouton, de gauche à droite.
  final List<String> buttons;

  /// Position du bouton actif, coloré comme la ligne choisie de la liste.
  final int? active;

  /// Appelé avec la position (à partir de 0) du bouton cliqué.
  final ValueChanged<int> onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final (i, label) in buttons.indexed)
          SectionButton(
            label: label,
            active: i == active,
            onPressed: () => onPressed(i),
          ),
      ],
    );
  }
}

/// Barre sombre, à coins arrondis, liseré et légère ombre comme les cartes, qui
/// prend toute la largeur disponible et centre ses boutons.
class SectionBar extends StatelessWidget {
  const SectionBar({super.key, required this.child});

  /// Marge intérieure au-dessus et au-dessous des boutons.
  static const double padding = 16;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Bourrelet dessiné par-dessus : il ne décale pas les boutons.
    return BevelEdge(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: padding, horizontal: 8),
        decoration: BoxDecoration(
          color: topBarColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: lightShadow,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Bouton texte : son libellé, sur fond bleu clair au survol, sans
/// animation. Actif, il est coloré comme la ligne choisie de la liste : fond
/// bleu, texte blanc.
class SectionButton extends StatelessWidget {
  const SectionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: topBarColor,
      // Actif : bordure grise un peu plus claire, comme l'élément choisi
      // d'une liste.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: active
            ? BorderSide(color: AccentStyle.of(context).border)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      // Actif : le fond texturé doré.
      child: Ink(
        decoration: active ? AccentStyle.of(context).texture : null,
        // Actif : pas de survol, son fond reste visible. La clé recrée l'encre
        // au changement d'état : un survol déjà affiché disparaît.
        child: InkWell(
          key: ValueKey(active),
          onTap: onPressed,
          // Survol bombé (voir [HoverBulge]), sauf s'il est actif.
          hoverColor: Colors.transparent,
          child: HoverBulge(
            enabled: !active,
            // Actif : en creux, comme le marque-page choisi (ombre portée
            // interne en haut).
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: active
                  ? const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x00000000)],
                        stops: [0, 0.4],
                      ),
                    )
                  : const BoxDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
    );
  }
}
