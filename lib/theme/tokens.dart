import 'package:flutter/material.dart';

/// Colours, spacing and sizes shared by every screen.
abstract final class Tokens {
  static const night = Color(0xFF15100C);
  static const panel = Color(0xFF241A13);
  static const panelRaised = Color(0xFF33251A);
  static const felt = Color(0xFF1E5547);
  static const feltDark = Color(0xFF123B31);
  static const wood = Color(0xFF6B4226);
  static const gold = Color(0xFFE8B04B);
  static const text = Color(0xFFF6EEDF);
  static const mutedText = Color(0xFFB7A894);
  static const danger = Color(0xFFE2695A);
  static const good = Color(0xFF7CC76B);

  /// Calza, kept apart from anything that looks like « confirm ».
  static const calza = Color(0xFF7FB2F0);
  static const outline = Colors.white12;

  /// The dice colours a player may pick. No two seats of a table share one.
  static const diceColors = [
    Color(0xFFD64541),
    Color(0xFFE8862E),
    Color(0xFFEBC634),
    Color(0xFF4CAF50),
    Color(0xFF26B5A5),
    Color(0xFF3F7FD9),
    Color(0xFF8E5BD0),
    Color(0xFFE56AA6),
    Color(0xFFEFE6D5),
    Color(0xFF3A3A44),
  ];

  static const diceColorNames = [
    'Rouge',
    'Orange',
    'Jaune',
    'Vert',
    'Turquoise',
    'Bleu',
    'Violet',
    'Rose',
    'Ivoire',
    'Noir',
  ];

  static Color dice(int index) => diceColors[index % diceColors.length];

  /// What reads well drawn on [color]: pips, initials.
  static Color on(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF1B1B1F) : Colors.white;

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space6 = 24.0;

  static const radiusButton = 12.0;
  static const radiusPanel = 18.0;

  /// Smallest comfortable touch target.
  static const tapTarget = 44.0;

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      surface: night,
      primary: gold,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: night,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: night,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(tapTarget, 48),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(tapTarget, 48),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
    );
  }
}
