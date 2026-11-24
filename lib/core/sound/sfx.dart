import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/session.dart';

/// المؤثرات الصوتية (أصوات أصلية من tool/make_sounds.py)
enum Sfx {
  done('done.wav'),
  coin('coin.wav'),
  celebrate('celebrate.wav'),
  tick('tick.wav'),
  milestone('milestone.wav');

  const Sfx(this.file);
  final String file;
}

/// الأصوات والاهتزاز: بيحترموا إعدادات المستخدم ووضع الصامت
class SoundSettings {
  const SoundSettings({this.sounds = true, this.haptics = true});
  final bool sounds;
  final bool haptics;
}

class SoundSettingsController extends Notifier<SoundSettings> {
  @override
  SoundSettings build() {
    final p = ref.read(sharedPrefsProvider);
    final s = SoundSettings(
      sounds: p.getBool('sfx_sounds') ?? true,
      haptics: p.getBool('sfx_haptics') ?? true,
    );
    SoundFx.settings = s;
    return s;
  }

  Future<void> update({bool? sounds, bool? haptics}) async {
    final p = ref.read(sharedPrefsProvider);
    if (sounds != null) await p.setBool('sfx_sounds', sounds);
    if (haptics != null) await p.setBool('sfx_haptics', haptics);
    state = build();
  }
}

final soundSettingsProvider =
    NotifierProvider<SoundSettingsController, SoundSettings>(
      SoundSettingsController.new,
    );

class SoundFx {
  SoundFx._();

  /// آخر إعدادات (بتتحدث من SoundSettingsController)
  static SoundSettings settings = const SoundSettings();

  /// الاختبارات مفيهاش مشغّل صوت
  static final bool _inTest = Platform.environment.containsKey('FLUTTER_TEST');

  static final Map<Sfx, AudioPlayer> _players = {};

  /// صوت «تنبيهات النظام»: بيسكت لوحده لو الموبايل صامت، ومبياخدش التركيز من الموسيقى
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.assistanceSonification,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  static AudioPlayer? _previewPlayer;

  /// تجربة صوت (زي الأذان) من الإعدادات؛ دوسة تانية بتوقفه
  static Future<void> preview(String file) async {
    if (_inTest) return;
    try {
      final p = _previewPlayer ??= AudioPlayer();
      if (p.state == PlayerState.playing) {
        await p.stop();
        return;
      }
      await p.play(AssetSource('sounds/$file'));
    } catch (_) {}
  }

  static Future<void> play(Sfx sfx, {bool haptic = true}) async {
    if (_inTest) return;
    if (haptic && settings.haptics) {
      switch (sfx) {
        case Sfx.tick:
          HapticFeedback.selectionClick();
        case Sfx.milestone || Sfx.celebrate:
          HapticFeedback.heavyImpact();
        default:
          HapticFeedback.lightImpact();
      }
    }
    if (!settings.sounds) return;
    try {
      final player = _players[sfx] ??= AudioPlayer();
      await player.setAudioContext(_context);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.stop();
      await player.play(AssetSource('sounds/${sfx.file}'), volume: 0.7);
    } catch (_) {
      // الصوت حاجة تجميلية: لو فشل منوقفش التطبيق
    }
  }
}
