import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'palettes.dart';
import '../widgets/hayati_background.dart';

class AppTheme {
  /// بيتقفل في سكريبت لقطات الشاشة (مفيش إنترنت لتحميل الخط)
  static bool useGoogleFonts = true;
  static String? fallbackFontFamily;
  static List<String>? fontFamilyFallback;

  static ThemeData light() => fromPalette(warmSand);
  static ThemeData dark() => fromPalette(emeraldNight);

  static ThemeData fromPalette(HayatiPalette p) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.primary,
          brightness: p.brightness,
        ).copyWith(
          primary: p.primary,
          onPrimary: p.onPrimary,
          secondary: p.accent,
          onSecondary: p.onAccent,
          tertiary: p.accent,
          surface: p.bgBottom,
          onSurface: p.text,
          onSurfaceVariant: p.muted,
          surfaceContainerLow: p.card,
          surfaceContainerHighest: p.track,
          outline: p.muted,
          outlineVariant: p.track,
          error: AppColors.danger,
        );
    return _build(scheme, p);
  }

  static ThemeData _build(ColorScheme scheme, HayatiPalette p) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // الخلفية شفافة: التدرّج بيترسم مرة واحدة تحت التطبيق كله (HayatiBackground)
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: p.bgBottom,
      extensions: [PaletteExtension(p)],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: HayatiPageTransitionsBuilder(),
          TargetPlatform.iOS: HayatiPageTransitionsBuilder(),
          TargetPlatform.linux: HayatiPageTransitionsBuilder(),
          TargetPlatform.macOS: HayatiPageTransitionsBuilder(),
          TargetPlatform.windows: HayatiPageTransitionsBuilder(),
          TargetPlatform.fuchsia: HayatiPageTransitionsBuilder(),
        },
      ),
    );
    final text = useGoogleFonts
        ? GoogleFonts.cairoTextTheme(base.textTheme)
        : base.textTheme.apply(
            fontFamily: fallbackFontFamily,
            fontFamilyFallback: fontFamilyFallback,
          );
    final themed = text.apply(bodyColor: p.text, displayColor: p.text);
    return base.copyWith(
      textTheme: themed,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: themed.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accent.withValues(alpha: 0.22),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.accent : p.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => themed.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? p.accent : p.muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bgTop,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: p.muted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bgTop,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: p.track),
      listTileTheme: ListTileThemeData(iconColor: p.accent, textColor: p.text),
      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: p.accent.withValues(alpha: 0.28),
        side: BorderSide(color: p.cardBorder),
        labelStyle: themed.labelLarge?.copyWith(color: p.text),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.accent,
        contentTextStyle: themed.bodyMedium?.copyWith(
          color: p.onAccent,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
