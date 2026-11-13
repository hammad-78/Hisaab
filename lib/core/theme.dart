import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hisaab colour tokens: a cafe's ledger book (khata) written in ballpoint ink.
/// Widgets read these through `context.h` so light and dark both work.
@immutable
class HTokens extends ThemeExtension<HTokens> {
  const HTokens({
    required this.ink,
    required this.onInk,
    required this.inkSoft,
    required this.paper,
    required this.slip,
    required this.rule,
    required this.graphite,
    required this.pencil,
    required this.khataRed,
  });

  final Color ink; // actions, selection, totals
  final Color onInk; // text/icons on ink
  final Color inkSoft; // selected tiles, light fills
  final Color paper; // app background
  final Color slip; // order slip, sheets, list surfaces
  final Color rule; // ruled lines
  final Color graphite; // primary text
  final Color pencil; // secondary text
  final Color khataRed; // slip margin line, destructive

  /// Daylight ledger: cool paper, blue ballpoint.
  static const light = HTokens(
    ink: Color(0xFF1F3A93),
    onInk: Color(0xFFFFFFFF),
    inkSoft: Color(0xFFE3E9F7),
    paper: Color(0xFFF4F6F9),
    slip: Color(0xFFFFFFFF),
    rule: Color(0xFFD5DCE6),
    graphite: Color(0xFF1C2230),
    pencil: Color(0xFF5F6878),
    khataRed: Color(0xFFA4262C),
  );

  /// Night ledger: slate pages, the same ink lifted so it stays readable.
  static const dark = HTokens(
    ink: Color(0xFF9DB4F5),
    onInk: Color(0xFF0E1A3D),
    inkSoft: Color(0xFF243259),
    paper: Color(0xFF141922),
    slip: Color(0xFF1C2230),
    rule: Color(0xFF323B4D),
    graphite: Color(0xFFE8ECF3),
    pencil: Color(0xFFA7B0BF),
    khataRed: Color(0xFFE5787D),
  );

  @override
  HTokens copyWith() => this;

  @override
  HTokens lerp(ThemeExtension<HTokens>? other, double t) {
    if (other is! HTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return HTokens(
      ink: c(ink, other.ink),
      onInk: c(onInk, other.onInk),
      inkSoft: c(inkSoft, other.inkSoft),
      paper: c(paper, other.paper),
      slip: c(slip, other.slip),
      rule: c(rule, other.rule),
      graphite: c(graphite, other.graphite),
      pencil: c(pencil, other.pencil),
      khataRed: c(khataRed, other.khataRed),
    );
  }
}

extension HTokensContext on BuildContext {
  HTokens get h => Theme.of(this).extension<HTokens>()!;
}

extension HTokensTheme on ThemeData {
  HTokens get h => extension<HTokens>()!;
}

/// Figures that line up in columns.
const tabular = [FontFeature.tabularFigures()];

/// Minimum touch target for counter controls (skill: POS targets 48-56dp).
const kTouch = 48.0;

/// [localFontFamily] is only for screenshot tests, which can't download fonts.
ThemeData buildTheme(Brightness brightness, {String? localFontFamily}) {
  final h = brightness == Brightness.dark ? HTokens.dark : HTokens.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: HTokens.light.ink,
    brightness: brightness,
    primary: h.ink,
    onPrimary: h.onInk,
    surface: h.paper,
    onSurface: h.graphite,
    onSurfaceVariant: h.pencil,
    outline: h.rule,
    outlineVariant: h.rule,
    error: h.khataRed,
    surfaceContainerLowest: h.slip,
    surfaceContainerLow: h.slip,
    surfaceContainer: h.slip,
    surfaceContainerHigh: h.slip,
    surfaceContainerHighest: h.inkSoft,
  );

  final typography = brightness == Brightness.dark
      ? Typography.material2021().white
      : Typography.material2021().black;
  final base =
      (localFontFamily == null
              ? GoogleFonts.atkinsonHyperlegibleNextTextTheme(typography)
              : typography.apply(fontFamily: localFontFamily))
          .apply(bodyColor: h.graphite, displayColor: h.graphite);
  final text = base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: base.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 15,
    ),
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: text,
    extensions: [h],
    scaffoldBackgroundColor: h.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: h.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: h.graphite,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
      shape: Border(bottom: BorderSide(color: h.rule)),
    ),
    dividerTheme: DividerThemeData(color: h.rule, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: h.slip,
      border: border(h.rule),
      enabledBorder: border(h.rule),
      focusedBorder: border(h.ink, 2),
      errorBorder: border(h.khataRed),
      focusedErrorBorder: border(h.khataRed, 2),
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
        minimumSize: const Size.fromHeight(kTouch),
        side: BorderSide(color: h.rule),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(kTouch, kTouch),
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(kTouch, kTouch)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: h.slip,
      selectedColor: h.ink,
      side: BorderSide(color: h.rule),
      labelStyle: text.labelLarge?.copyWith(color: h.graphite),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: h.onInk),
      checkmarkColor: h.onInk,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: h.slip,
      indicatorColor: h.inkSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: h.ink,
      foregroundColor: h.onInk,
      elevation: 1,
    ),
    listTileTheme: ListTileThemeData(iconColor: h.pencil),
    dialogTheme: DialogThemeData(backgroundColor: h.slip),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
