import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

class HayatiDates {
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h >= 4 && h < 12) return 'صباح الخير';
    if (h >= 12 && h < 17) return 'نهارك سعيد';
    return 'مساء الخير';
  }

  static String gregorian(DateTime d) =>
      DateFormat('EEEE، d MMMM y', 'ar').format(d);

  static String hijri(DateTime d) {
    HijriCalendar.setLocal('ar');
    final h = HijriCalendar.fromDate(d);
    return '${h.hDay} ${h.longMonthName} ${h.hYear} هـ';
  }

  static String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}
