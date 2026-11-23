import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/palettes.dart';
import 'session.dart';

/// الثيم المختار (زمرّدي ليلي هو الأساسي)
class PaletteController extends Notifier<HayatiPalette> {
  static const _key = 'palette_id';

  @override
  HayatiPalette build() =>
      paletteById(ref.read(sharedPrefsProvider).getString(_key));

  Future<void> set(HayatiPalette p) async {
    state = p;
    await ref.read(sharedPrefsProvider).setString(_key, p.id);
  }
}

final paletteProvider = NotifierProvider<PaletteController, HayatiPalette>(
  PaletteController.new,
);

/// حجم الخط في التطبيق كله
final textScaleNames = <double, String>{
  0.9: 'صغير',
  1.0: 'عادي',
  1.15: 'كبير',
  1.3: 'كبير جدًا',
};

class TextScaleController extends Notifier<double> {
  static const _key = 'text_scale';

  @override
  double build() {
    final v = ref.read(sharedPrefsProvider).getDouble(_key) ?? 1.0;
    return textScaleNames.containsKey(v) ? v : 1.0;
  }

  Future<void> set(double v) async {
    state = v;
    await ref.read(sharedPrefsProvider).setDouble(_key, v);
  }
}

final textScaleProvider = NotifierProvider<TextScaleController, double>(
  TextScaleController.new,
);
