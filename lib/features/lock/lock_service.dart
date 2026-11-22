import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/session.dart';

/// قفل التطبيق: رمز PIN (مُشفَّر بـ SHA-256 + salt في التخزين الآمن) + بصمة اختيارية
class LockState {
  const LockState({
    required this.enabled,
    required this.locked,
    required this.biometrics,
  });
  final bool enabled;
  final bool locked;
  final bool biometrics;

  LockState copyWith({bool? enabled, bool? locked, bool? biometrics}) =>
      LockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
        biometrics: biometrics ?? this.biometrics,
      );
}

class LockController extends Notifier<LockState> {
  static const _enabledKey = 'lock_enabled';
  static const _bioKey = 'lock_biometrics';
  static const _pinKey = 'lock_pin_hash';
  static const _saltKey = 'lock_pin_salt';
  static const _storage = FlutterSecureStorage();
  final _auth = LocalAuthentication();
  DateTime? _pausedAt;

  @override
  LockState build() {
    final prefs = ref.read(sharedPrefsProvider);
    final enabled = prefs.getBool(_enabledKey) ?? false;
    return LockState(
      enabled: enabled,
      locked: enabled,
      biometrics: prefs.getBool(_bioKey) ?? false,
    );
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> enable(String pin, {required bool biometrics}) async {
    final salt = base64Url.encode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _pinKey, value: _hash(pin, salt));
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool(_enabledKey, true);
    await prefs.setBool(_bioKey, biometrics);
    state = LockState(enabled: true, locked: false, biometrics: biometrics);
  }

  Future<void> disable() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _saltKey);
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool(_enabledKey, false);
    await prefs.setBool(_bioKey, false);
    state = const LockState(enabled: false, locked: false, biometrics: false);
  }

  Future<bool> unlockWithPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final hash = await _storage.read(key: _pinKey);
    if (salt == null || hash == null) return false;
    final ok = _hash(pin, salt) == hash;
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'افتح «حياتي» ببصمتك',
        biometricOnly: true,
      );
      if (ok) state = state.copyWith(locked: false);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// يُستدعى عند خروج التطبيق للخلفية
  void onPaused() => _pausedAt = DateTime.now();

  /// يُقفل التطبيق لو فضل في الخلفية أكتر من 30 ثانية
  void onResumed() {
    final paused = _pausedAt;
    _pausedAt = null;
    if (!state.enabled || paused == null) return;
    if (DateTime.now().difference(paused).inSeconds >= 30) {
      state = state.copyWith(locked: true);
    }
  }
}

final lockProvider =
    NotifierProvider<LockController, LockState>(LockController.new);
