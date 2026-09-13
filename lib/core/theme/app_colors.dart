import 'package:flutter/material.dart';

/// Paleta extraída do layout de login enviado (tons de marrom/creme,
/// remetendo a pelagem de cachorro/gato). Único tema por enquanto —
/// sem modo escuro, já que não foi pedido.
abstract final class AppColors {
  static const Color brandDark = Color(0xFF3E2415);
  static const Color brandMedium = Color(0xFF5C3A24);
  static const Color brandLight = Color(0xFF7A5137);

  static const Color background = Color(0xFFFBEADD);
  static const Color surface = Color(0xFFFFF8F0);

  static const Color textOnBrand = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF3E2415);
  static const Color textMuted = Color(0xFF9C7B5F);

  static const Color error = Color(0xFFB3261E);

  /// Mesmo valor de `AppPalette.padrao.success` — reaproveitado aqui (não
  /// duplicado com um tom diferente) porque esta tela ainda não foi
  /// migrada para `context.colors` (ver docs/features/
  /// theme-and-settings-menu.md, "Hardcodes restantes").
  static const Color success = Color(0xFF2E7D32);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandDark, brandLight],
  );

  /// Fundo claro atrás do card branco da Home (RF11), inspirado no mockup
  /// enviado pelo usuário.
  static const Color homeBackdrop = Color(0xFFEEF1FA);

  /// Paleta cíclica dos cards de pet na Home — fundo pastel + cor de
  /// destaque (selo de espécie, badge de gênero, botão de seta), uma
  /// combinação por índice na lista.
  static const List<Color> petCardBackgrounds = [
    Color(0xFFEDE7F6),
    Color(0xFFFFF3E0),
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
  ];
  static const List<Color> petCardAccents = [
    Color(0xFF7E57C2),
    Color(0xFFFB8C00),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
  ];
}
