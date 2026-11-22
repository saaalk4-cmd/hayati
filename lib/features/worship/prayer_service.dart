import 'package:adhan/adhan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'prayer_settings.dart';

enum PrayerName { fajr, dhuhr, asr, maghrib, isha }

extension PrayerNameAr on PrayerName {
  String get ar => const {
    PrayerName.fajr: 'الفجر',
    PrayerName.dhuhr: 'الظهر',
    PrayerName.asr: 'العصر',
    PrayerName.maghrib: 'المغرب',
    PrayerName.isha: 'العشاء',
  }[this]!;
}

class DayPrayerTimes {
  DayPrayerTimes(this.date, this.times, this.sunrise);
  final DateTime date;
  final Map<PrayerName, DateTime> times;
  final DateTime sunrise;

  DateTime operator [](PrayerName p) => times[p]!;
}

/// حساب المواقيت محليًا على الموبايل (من غير إنترنت) بمكتبة adhan
DayPrayerTimes computePrayerTimes(PrayerSettings s, DateTime day) {
  final pt = PrayerTimes(
    s.coordinates,
    DateComponents(day.year, day.month, day.day),
    s.parameters,
  );
  return DayPrayerTimes(DateTime(day.year, day.month, day.day), {
    PrayerName.fajr: pt.fajr.toLocal(),
    PrayerName.dhuhr: pt.dhuhr.toLocal(),
    PrayerName.asr: pt.asr.toLocal(),
    PrayerName.maghrib: pt.maghrib.toLocal(),
    PrayerName.isha: pt.isha.toLocal(),
  }, pt.sunrise.toLocal());
}

class NextPrayer {
  const NextPrayer(this.name, this.time);
  final PrayerName name;
  final DateTime time;
}

NextPrayer nextPrayer(PrayerSettings s, DateTime now) {
  final today = computePrayerTimes(s, now);
  for (final p in PrayerName.values) {
    if (today[p].isAfter(now)) return NextPrayer(p, today[p]);
  }
  final tomorrow = computePrayerTimes(s, now.add(const Duration(days: 1)));
  return NextPrayer(PrayerName.fajr, tomorrow[PrayerName.fajr]);
}

String formatPrayerTime(DateTime t) => DateFormat('h:mm a', 'ar').format(t);

String formatCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return 'بعد $h س و $m د';
  if (m > 0) return 'بعد $m دقيقة';
  return 'دلوقتي';
}

/// ساعة بتتحدث كل دقيقة عشان العدّاد التنازلي
final minuteClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

final todayPrayerTimesProvider = Provider<DayPrayerTimes>((ref) {
  final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
  return computePrayerTimes(ref.watch(prayerSettingsProvider), now);
});

final nextPrayerProvider = Provider<NextPrayer>((ref) {
  final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
  return nextPrayer(ref.watch(prayerSettingsProvider), now);
});
