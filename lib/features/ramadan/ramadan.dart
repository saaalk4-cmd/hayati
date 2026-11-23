import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../data/user_store.dart';

/// معلومات رمضان بالنسبة لتاريخ معيّن
class RamadanInfo {
  const RamadanInfo({
    required this.hijriYear,
    required this.isRamadan,
    required this.day,
    required this.daysUntilRamadan,
    required this.daysUntilEid,
  });

  final int hijriYear;
  final bool isRamadan;

  /// اليوم كام في رمضان (لو في رمضان)
  final int day;

  /// فاضل كام يوم على رمضان (لو مش في رمضان)
  final int daysUntilRamadan;

  /// فاضل كام يوم على العيد (لو في رمضان)
  final int daysUntilEid;

  bool get isLastTen => isRamadan && day >= 21;
}

/// [adjustDays]: تعديل التاريخ الهجري ±1 حسب رؤية الهلال في بلدك
RamadanInfo ramadanInfo(DateTime now, {int adjustDays = 0}) {
  final d = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: adjustDays));
  final h = HijriCalendar.fromDate(d);
  if (h.hMonth == 9) {
    final len = h.getDaysInMonth(h.hYear, 9);
    return RamadanInfo(
      hijriYear: h.hYear,
      isRamadan: true,
      day: h.hDay,
      daysUntilRamadan: 0,
      daysUntilEid: len - h.hDay + 1,
    );
  }
  // أول رمضان الجاي
  final year = h.hMonth < 9 ? h.hYear : h.hYear + 1;
  final start = HijriCalendar().hijriToGregorian(year, 9, 1);
  final days = DateTime(
    start.year,
    start.month,
    start.day,
  ).difference(d).inDays;
  return RamadanInfo(
    hijriYear: year,
    isRamadan: false,
    day: 0,
    daysUntilRamadan: days,
    daysUntilEid: 0,
  );
}

/// سجل رمضان: users/{uid}/ramadan/{hijriYear} => {fasted: {1: true}, taraweeh: {1: true}}
class RamadanLog {
  const RamadanLog({this.fasted = const {}, this.taraweeh = const {}});
  final Set<int> fasted;
  final Set<int> taraweeh;
}

final ramadanLogProvider = StreamProvider.family<RamadanLog, int>((ref, year) {
  return ref.watch(userStoreProvider).watch('ramadan', '$year').map((d) {
    Set<int> days(Object? m) => {
      for (final e in ((m as Map?) ?? const {}).entries)
        if (e.value == true) int.parse('${e.key}'),
    };
    return RamadanLog(
      fasted: days(d?['fasted']),
      taraweeh: days(d?['taraweeh']),
    );
  });
});

Future<void> setRamadanDay(
  WidgetRef ref,
  int year,
  int day, {
  bool? fasted,
  bool? taraweeh,
}) {
  return ref.read(userStoreProvider).merge('ramadan', '$year', {
    if (fasted != null) 'fasted': {'$day': fasted},
    if (taraweeh != null) 'taraweeh': {'$day': taraweeh},
  });
}
