import 'package:flutter/material.dart';

import 'top_bar.dart';

/// Colonne de boutons ronds, chacun avec une icône, empilés de haut en bas
/// sur le bord gauche de l'écran, au style de la barre de menu.
class SideButtons extends StatelessWidget {
  const SideButtons({super.key, required this.buttons});

  /// Icône et libellé de chaque bouton, de haut en bas.
  final List<(IconData, String)> buttons;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          for (final (icon, label) in buttons)
            SideButton(
              icon: icon,
              label: label,
              // Aucune action pour l'instant.
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}

/// Bouton rond avec une icône. Au survol (ou au focus clavier), il s'étire
/// vers la droite pour laisser apparaître son libellé.
class SideButton extends StatefulWidget {
  const SideButton({
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
  State<SideButton> createState() => _SideButtonState();
}

class _SideButtonState extends State<SideButton> {
  bool _hovered = false;
  bool _focused = false;

  bool get _expanded => _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: topBarColor,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            onFocusChange: (f) => setState(() => _focused = f),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: SideButton.size,
                    child: Icon(widget.icon),
                  ),
                  if (_expanded)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        widget.label,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
