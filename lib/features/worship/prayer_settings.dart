import 'package:adhan/adhan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/session.dart';

/// إعدادات المواقيت (محفوظة على الجهاز لأنها مرتبطة بمكانه)
class PrayerSettings {
  const PrayerSettings({
    required this.latitude,
    required this.longitude,
    required this.placeLabel,
    required this.method,
    required this.madhab,
    required this.adhanNotifications,
    required this.hasRealLocation,
  });

  final double latitude;
  final double longitude;
  final String placeLabel;
  final CalculationMethod method;
  final Madhab madhab;
  final bool adhanNotifications;

  /// false لو لسه بنستخدم القاهرة كموقع افتراضي
  final bool hasRealLocation;

  Coordinates get coordinates => Coordinates(latitude, longitude);

  CalculationParameters get parameters =>
      method.getParameters()..madhab = madhab;

  PrayerSettings copyWith({
    double? latitude,
    double? longitude,
    String? placeLabel,
    CalculationMethod? method,
    Madhab? madhab,
    bool? adhanNotifications,
    bool? hasRealLocation,
  }) =>
      PrayerSettings(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        placeLabel: placeLabel ?? this.placeLabel,
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
        adhanNotifications: adhanNotifications ?? this.adhanNotifications,
        hasRealLocation: hasRealLocation ?? this.hasRealLocation,
      );
}

/// طرق الحساب المعروضة للمستخدم
const calculationMethodNames = <CalculationMethod, String>{
  CalculationMethod.egyptian: 'الهيئة المصرية العامة للمساحة',
  CalculationMethod.umm_al_qura: 'أم القرى (مكة المكرمة)',
  CalculationMethod.muslim_world_league: 'رابطة العالم الإسلامي',
  CalculationMethod.dubai: 'الخليج (دبي)',
  CalculationMethod.kuwait: 'الكويت',
  CalculationMethod.qatar: 'قطر',
  CalculationMethod.karachi: 'جامعة العلوم الإسلامية (كراتشي)',
  CalculationMethod.turkey: 'رئاسة الشؤون الدينية التركية',
  CalculationMethod.north_america: 'أمريكا الشمالية (ISNA)',
};

class PrayerSettingsController extends Notifier<PrayerSettings> {
  static const _p = 'prayer_';

  @override
  PrayerSettings build() {
    final prefs = ref.read(sharedPrefsProvider);
    final method = CalculationMethod.values.firstWhere(
      (m) => m.name == prefs.getString('${_p}method'),
      orElse: () => CalculationMethod.egyptian,
    );
    return PrayerSettings(
      latitude: prefs.getDouble('${_p}lat') ?? 30.0444,
      longitude: prefs.getDouble('${_p}lng') ?? 31.2357,
      placeLabel: prefs.getString('${_p}place') ?? 'القاهرة (افتراضي)',
      method: method,
      madhab: prefs.getString('${_p}madhab') == 'hanafi'
          ? Madhab.hanafi
          : Madhab.shafi,
      adhanNotifications: prefs.getBool('${_p}adhan') ?? true,
      hasRealLocation: prefs.getDouble('${_p}lat') != null,
    );
  }

  Future<void> _save(PrayerSettings s) async {
    final prefs = ref.read(sharedPrefsProvider);
    if (s.hasRealLocation) {
      await prefs.setDouble('${_p}lat', s.latitude);
      await prefs.setDouble('${_p}lng', s.longitude);
      await prefs.setString('${_p}place', s.placeLabel);
    }
    await prefs.setString('${_p}method', s.method.name);
    await prefs.setString('${_p}madhab', s.madhab.name);
    await prefs.setBool('${_p}adhan', s.adhanNotifications);
    state = s;
  }

  Future<void> setMethod(CalculationMethod m) => _save(state.copyWith(method: m));
  Future<void> setMadhab(Madhab m) => _save(state.copyWith(madhab: m));
  Future<void> setAdhan(bool v) => _save(state.copyWith(adhanNotifications: v));

  /// يحدد الموقع الحالي. يرجّع رسالة خطأ بالعربي أو null لو نجح.
  Future<String?> detectLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'شغّل الـ GPS (خدمة الموقع) الأول';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return 'محتاجين إذن الموقع عشان نحسب المواقيت بدقة';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _save(state.copyWith(
        latitude: pos.latitude,
        longitude: pos.longitude,
        placeLabel:
            'موقعك الحالي (${pos.latitude.toStringAsFixed(2)}، ${pos.longitude.toStringAsFixed(2)})',
        hasRealLocation: true,
      ));
      return null;
    } catch (_) {
      return 'معرفناش نحدد موقعك، جرّب تاني';
    }
  }
}

final prayerSettingsProvider =
    NotifierProvider<PrayerSettingsController, PrayerSettings>(
        PrayerSettingsController.new);
