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
