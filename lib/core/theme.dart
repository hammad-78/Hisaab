import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hisaab palette: a cafe's ledger book (khata) written in ballpoint ink.
class HColors {
  static const ink = Color(0xFF1F3A93); // ballpoint blue: actions, selection, totals
  static const inkSoft = Color(0xFFE3E9F7); // selected tiles, light fills
  static const paper = Color(0xFFF4F6F9); // app background
  static const slip = Color(0xFFFFFFFF); // order slip, sheets
  static const rule = Color(0xFFD5DCE6); // ruled lines
  static const graphite = Color(0xFF1C2230); // text
  static const pencil = Color(0xFF5F6878); // secondary text
  static const khataRed = Color(0xFFA4262C); // slip margin line, destructive
}

/// Figures that line up in columns.
const tabular = [FontFeature.tabularFigures()];

/// [localFontFamily] is only for screenshot tests, which can't download fonts.
ThemeData buildTheme({String? localFontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: HColors.ink,
    primary: HColors.ink,
    onPrimary: Colors.white,
    surface: HColors.paper,
    onSurface: HColors.graphite,
    onSurfaceVariant: HColors.pencil,
    outline: HColors.rule,
    outlineVariant: HColors.rule,
    error: HColors.khataRed,
    surfaceContainerLowest: HColors.slip,
    surfaceContainerLow: HColors.slip,
    surfaceContainer: HColors.slip,
    surfaceContainerHigh: HColors.slip,
    surfaceContainerHighest: HColors.inkSoft,
  );

  final base = (localFontFamily == null
          ? GoogleFonts.atkinsonHyperlegibleNextTextTheme()
          : Typography.material2021().black.apply(fontFamily: localFontFamily))
      .apply(bodyColor: HColors.graphite, displayColor: HColors.graphite);
  final text = base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: HColors.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: HColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: HColors.graphite,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
      shape: const Border(bottom: BorderSide(color: HColors.rule)),
    ),
    dividerTheme: const DividerThemeData(color: HColors.rule, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HColors.slip,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: HColors.rule)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: HColors.rule)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: HColors.ink, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: HColors.rule),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: HColors.slip,
      selectedColor: HColors.ink,
      side: const BorderSide(color: HColors.rule),
      labelStyle: text.labelLarge?.copyWith(color: HColors.graphite),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: Colors.white),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: HColors.slip,
      indicatorColor: HColors.inkSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: HColors.ink,
      foregroundColor: Colors.white,
      elevation: 1,
    ),
    listTileTheme: const ListTileThemeData(iconColor: HColors.pencil),
    dialogTheme: const DialogThemeData(backgroundColor: HColors.slip),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
