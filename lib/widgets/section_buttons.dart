import 'package:flutter/material.dart';

import 'top_bar.dart';

/// Rangée horizontale de boutons ronds, chacun avec une icône, au style de la
/// barre de menu.
class SectionButtons extends StatelessWidget {
  const SectionButtons({
    super.key,
    required this.buttons,
    required this.onPressed,
  });

  /// Icône et libellé (pour les lecteurs d'écran) de chaque bouton, de gauche
  /// à droite.
  final List<(IconData, String)> buttons;

  /// Appelé avec la position (à partir de 0) du bouton cliqué.
  final ValueChanged<int> onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final (i, (icon, label)) in buttons.indexed)
          SectionButton(
            icon: icon,
            label: label,
            onPressed: () => onPressed(i),
          ),
      ],
    );
  }
}

/// Bouton rond avec une icône, sans animation au survol.
class SectionButton extends StatelessWidget {
  const SectionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const double size = 40;

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: topBarColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(dimension: size, child: Icon(icon)),
        ),
      ),
    );
  }
}
