import 'package:flutter/material.dart';

/// Barre de menu en haut de l'écran, juste assez haute pour un texte de 14px.
/// Affiche au centre un groupe d'informations (icône + nombre).
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.items});

  final List<TopBarInfo> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: items,
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
