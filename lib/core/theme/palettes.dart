import 'package:material_ui/material_ui.dart';

/// ثيمات «حياتي» — مفيش أبيض خالص في أي واحد فيهم
class HayatiPalette {
  const HayatiPalette({
    required this.id,
    required this.name,
    required this.brightness,
    required this.bgTop,
    required this.bgBottom,
    required this.card,
    required this.cardBorder,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.text,
    required this.muted,
    required this.heroTop,
    required this.heroBottom,
    required this.track,
  });

  final String id;
  final String name;
  final Brightness brightness;

  /// تدرّج خلفية التطبيق كله
  final Color bgTop;
  final Color bgBottom;

  /// الكروت (زجاجية) وحافتها
  final Color card;
  final Color cardBorder;
  final Color primary;
  final Color onPrimary;

  /// الذهبي
  final Color accent;
  final Color onAccent;
  final Color text;
  final Color muted;

  /// تدرّج بطاقات «البطل» (الصلاة الجاية، الملخصات)
  final Color heroTop;
  final Color heroBottom;

  /// خلفية أشرطة التقدّم والدواير الفاضية
  final Color track;

  bool get isDark => brightness == Brightness.dark;

  LinearGradient get background => LinearGradient(
    colors: [bgTop, bgBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  LinearGradient get hero => LinearGradient(
    colors: [heroTop, heroBottom],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

const emeraldNight = HayatiPalette(
  id: 'emerald',
  name: 'زمرّدي ليلي',
  brightness: Brightness.dark,
  bgTop: Color(0xFF113428),
  bgBottom: Color(0xFF06150F),
  card: Color(0xCC17392E),
  cardBorder: Color(0x33D4AF5A),
  primary: Color(0xFF3FA27F),
  onPrimary: Color(0xFF04150F),
  accent: Color(0xFFD4AF5A),
  onAccent: Color(0xFF1A1405),
  text: Color(0xFFF4EEDF),
  muted: Color(0xFFA8BCB2),
  heroTop: Color(0xFF237055),
  heroBottom: Color(0xFF0C3326),
  track: Color(0x33F4EEDF),
);

const royalNavy = HayatiPalette(
  id: 'navy',
  name: 'كحلي ملكي',
  brightness: Brightness.dark,
  bgTop: Color(0xFF16264A),
  bgBottom: Color(0xFF070D1C),
  card: Color(0xCC1B2D52),
  cardBorder: Color(0x33D4AF5A),
  primary: Color(0xFF6C9BEF),
  onPrimary: Color(0xFF06112A),
  accent: Color(0xFFD4AF5A),
  onAccent: Color(0xFF1A1405),
  text: Color(0xFFF2EFE6),
  muted: Color(0xFFAAB6CE),
  heroTop: Color(0xFF2D4F96),
  heroBottom: Color(0xFF111F42),
  track: Color(0x33F2EFE6),
);

const warmSand = HayatiPalette(
  id: 'sand',
  name: 'رملي دافي',
  brightness: Brightness.light,
  bgTop: Color(0xFFF0E5CF),
  bgBottom: Color(0xFFE2D1B0),
  card: Color(0xE6F8EEDA),
  cardBorder: Color(0x40A8832F),
  primary: Color(0xFF1F5E4A),
  onPrimary: Color(0xFFF8EEDA),
  accent: Color(0xFFA8832F),
  onAccent: Color(0xFFF8EEDA),
  text: Color(0xFF2B2418),
  muted: Color(0xFF6E6250),
  heroTop: Color(0xFF237055),
  heroBottom: Color(0xFF0C3326),
  track: Color(0x262B2418),
);

const allPalettes = [emeraldNight, royalNavy, warmSand];

HayatiPalette paletteById(String? id) =>
    allPalettes.firstWhere((p) => p.id == id, orElse: () => emeraldNight);

/// بيوصّل الثيم الحالي لأي ويدجت: `context.palette`
class PaletteExtension extends ThemeExtension<PaletteExtension> {
  const PaletteExtension(this.palette);
  final HayatiPalette palette;

  @override
  PaletteExtension copyWith({HayatiPalette? palette}) =>
      PaletteExtension(palette ?? this.palette);

  @override
  PaletteExtension lerp(ThemeExtension<PaletteExtension>? other, double t) =>
      t < 0.5 ? this : (other as PaletteExtension? ?? this);
}

extension PaletteContext on BuildContext {
  HayatiPalette get palette =>
      Theme.of(this).extension<PaletteExtension>()?.palette ?? emeraldNight;
}
