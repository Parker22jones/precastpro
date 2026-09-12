import 'package:flutter/material.dart';

/// Dense, spreadsheet-style visual language modelled on shop engineering
/// software: thin rules, square corners, tight rows, monospaced numerics.
class Mh {
  const Mh._();

  static const Color chrome = Color(0xFF1B2530);
  static const Color chromeLight = Color(0xFF27364A);
  static const Color accent = Color(0xFF0B6BCB);
  static const Color surface = Color(0xFFF4F5F7);
  static const Color field = Color(0xFFFFFFFF);
  static const Color gridLine = Color(0xFFB9C1CC);
  static const Color headerFill = Color(0xFFE3E8EF);
  static const Color text = Color(0xFF12202E);
  static const Color subtleText = Color(0xFF5A6B7C);
  static const Color danger = Color(0xFFC62828);
  static const Color warn = Color(0xFFF59F00);
  static const Color ok = Color(0xFF1B7F3B);

  /// Blueprint (CAD) palette.
  static const Color cadPaper = Color(0xFFFDFDFB);
  static const Color cadSlate = Color(0xFF16222E);
  static const Color cadInk = Color(0xFF102027);
  static const Color cadInkLight = Color(0xFFE6EDF3);
  static const Color cadDim = Color(0xFF0B6BCB);

  static const double rowHeight = 26;
  static const double headerHeight = 24;
  static const double gap = 6;

  static const TextStyle label = TextStyle(
    fontSize: 11,
    color: subtleText,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static const TextStyle cell = TextStyle(fontSize: 12, color: text);
  static const TextStyle cellNum = TextStyle(
    fontSize: 12,
    color: text,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle header = TextStyle(
    fontSize: 10.5,
    color: text,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 12,
    color: Colors.white,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static ThemeData themeData() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: base.colorScheme.copyWith(primary: accent, surface: surface, error: danger),
      visualDensity: VisualDensity.compact,
      dividerTheme: const DividerThemeData(color: gridLine, space: 1, thickness: 1),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: field,
        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: gridLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: gridLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: gridLine),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}
