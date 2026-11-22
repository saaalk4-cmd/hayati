import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

/// تنسيق تاريخ/وقت بالعربي بأرقام 0-9 (زي تصميم التطبيق) بدل ٠-٩
String arFormat(String pattern, DateTime d) =>
    latinDigits(DateFormat(pattern, 'ar').format(d));

String latinDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

class HayatiDates {
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h >= 4 && h < 12) return 'صباح الخير';
    if (h >= 12 && h < 17) return 'نهارك سعيد';
    return 'مساء الخير';
  }

  static String gregorian(DateTime d) => arFormat('EEEE، d MMMM y', d);

  static String hijri(DateTime d) {
    HijriCalendar.setLocal('ar');
    final h = HijriCalendar.fromDate(d);
    return '${h.hDay} ${h.longMonthName} ${h.hYear} هـ';
  }

  static String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}
