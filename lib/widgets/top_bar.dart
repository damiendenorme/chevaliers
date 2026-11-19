import 'package:flutter/material.dart';

/// Couleur de fond de la barre de menu, réutilisée par les boutons latéraux.
const topBarColor = Color(0xFF1E1E1E);

/// Barre de menu en haut de l'écran, juste assez haute pour un texte de 14px.
/// Affiche à gauche un titre, et au centre un groupe d'informations
/// (icône + nombre). Le groupe reste centré sur toute la largeur, quelle que
/// soit la longueur du titre.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    required this.items,
    this.trailing,
  });

  final String title;
  final List<Widget> items;

  /// Texte affiché à droite de la barre.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: topBarColor,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: const TextStyle(fontSize: 14)),
          ),
          if (trailing != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(trailing!, style: const TextStyle(fontSize: 14)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 16,
            children: items,
          ),
        ],
      ),
    );
  }
}

/// Une information de la barre : une icône suivie d'un nombre.
/// Tant que [value] est null, un tiret est affiché.
class TopBarInfo extends StatelessWidget {
  const TopBarInfo({
    super.key,
    required this.icon,
    required this.value,
    this.tooltip,
  });

  final IconData icon;
  final int? value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(icon, size: 16),
        Text(value?.toString() ?? '–', style: const TextStyle(fontSize: 14)),
      ],
    );
    return tooltip == null
        ? content
        : Tooltip(message: tooltip!, child: content);
  }
}
