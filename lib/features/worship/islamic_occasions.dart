import 'package:hijri/hijri_calendar.dart';

import '../../core/utils/date_utils.dart';

/// مناسبة إسلامية ثابتة في التقويم الهجري
class IslamicOccasion {
  const IslamicOccasion(
    this.id,
    this.name,
    this.month,
    this.day,
    this.emoji, {
    this.fasting = false,
    this.note,
  });
  final String id;
  final String name;
  final int month;
  final int day;
  final String emoji;

  /// صيام مستحب في اليوم ده
  final bool fasting;
  final String? note;
}

/// التواريخ الهجرية المعروفة للمناسبات (التواريخ بس، من غير نصوص)
const islamicOccasions = [
  IslamicOccasion('hijri_new_year', 'رأس السنة الهجرية', 1, 1, '🌙'),
  IslamicOccasion('tasua', 'يوم تاسوعاء', 1, 9, '🤲', fasting: true),
  IslamicOccasion('ashura', 'يوم عاشوراء', 1, 10, '🤲', fasting: true),
  IslamicOccasion('ramadan', 'بداية رمضان', 9, 1, '🏮'),
  IslamicOccasion(
    'last_ten',
    'العشر الأواخر من رمضان',
    9,
    21,
    '✨',
    note: 'تحرّي ليلة القدر',
  ),
  IslamicOccasion('eid_fitr', 'عيد الفطر', 10, 1, '🎉'),
  IslamicOccasion('arafah', 'يوم عرفة', 12, 9, '🕋', fasting: true),
  IslamicOccasion('eid_adha', 'عيد الأضحى', 12, 10, '🐑'),
];

class OccasionDate {
  const OccasionDate(this.occasion, this.date, this.hijriYear);
  final IslamicOccasion occasion;
  final DateTime date;
  final int hijriYear;

  int daysFrom(DateTime now) =>
      date.difference(DateTime(now.year, now.month, now.day)).inDays;
}

/// المرة الجاية لكل مناسبة (بالتقويم الهجري + تعديل الإعدادات)، مرتبة من الأقرب
List<OccasionDate> upcomingIslamicOccasions(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final adjust = HayatiDates.hijriAdjust;
  final h = HijriCalendar.fromDate(today.add(Duration(days: adjust)));
  final out = <OccasionDate>[];
  for (final o in islamicOccasions) {
    for (final year in [h.hYear, h.hYear + 1]) {
      final g = HijriCalendar().hijriToGregorian(year, o.month, o.day);
      // التاريخ الهجري المعروض = الميلادي + التعديل، فبنطرح التعديل
      final d = DateTime(
        g.year,
        g.month,
        g.day,
      ).subtract(Duration(days: adjust));
      if (!d.isBefore(today)) {
        out.add(OccasionDate(o, d, year));
        break;
      }
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}
