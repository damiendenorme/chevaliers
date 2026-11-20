import 'package:flutter/material.dart';

/// Couleur des zones posées sur le fond (barres, boutons, tableaux) : blanc.
const topBarColor = Colors.white;

/// Couleur des éléments actifs : bleu, avec le texte en blanc.
const accentColor = Color(0xFF2F6FDB);

/// Couleur des survols : bleu clair, pour garder le texte sombre lisible.
const hoverColor = Color(0xFFD6E4FB);

/// Légère ombre portée des boutons et des cartes.
const lightShadow = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 1)),
];

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

/// Pied de page, au même style et à la même hauteur que la barre de menu.
/// Vide pour l'instant : une ligne de texte vide de 14px lui donne exactement
/// la hauteur de la barre.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: topBarColor,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: const Text('', style: TextStyle(fontSize: 14)),
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
