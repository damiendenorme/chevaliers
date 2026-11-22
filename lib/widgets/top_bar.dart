import 'package:flutter/material.dart';

/// Couleur des zones posées sur le fond (boutons, cartes) : blanc.
const topBarColor = Colors.white;

/// Couleur des éléments actifs : bleu, avec le texte en blanc.
const accentColor = Color(0xFF2F6FDB);

/// Couleur des survols : bleu clair, pour garder le texte sombre lisible.
const hoverColor = Color(0xFFD6E4FB);

/// Légère ombre portée des boutons et des cartes.
const lightShadow = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 1)),
];
