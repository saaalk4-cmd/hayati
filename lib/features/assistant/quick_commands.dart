// الأوامر السريعة: بتفهم جمل مصرية بسيطة من غير نت ومن غير ذكاء اصطناعي.
// الملف ده «فهم» بس (من غير Riverpod) عشان يتختبر بسهولة؛ التنفيذ في quick_assistant.dart

import '../search/global_search.dart' show normalizeArabic;
import '../worship/prayer_service.dart';

sealed class QuickCommand {
  const QuickCommand();
}

class AddExpense extends QuickCommand {
  const AddExpense(this.amount, this.category, this.note);
  final double amount;
  final String category;
  final String note;
}

class AddIncome extends QuickCommand {
  const AddIncome(this.amount, this.category, this.note);
  final double amount;
  final String category;
  final String note;
}

class AddTaskCommand extends QuickCommand {
  const AddTaskCommand(this.title, {this.dueDate, this.remindAt});
  final String title;
  final DateTime? dueDate;
  final DateTime? remindAt;
}

class LogPrayers extends QuickCommand {
  const LogPrayers(this.prayers, {this.mosque = false});
  final List<PrayerName> prayers;
  final bool mosque;
}

class LogQuran extends QuickCommand {
  const LogQuran(this.pages);
  final int pages;
}

/// «عملت الرياضة» / «خلصت المذاكرة»: عادة أو مهمة بالاسم
class MarkDone extends QuickCommand {
  const MarkDone(this.name);
  final String name;
}

class AskNextPrayer extends QuickCommand {
  const AskNextPrayer([this.prayer]);
  final PrayerName? prayer;
}

class AskPrayerTimes extends QuickCommand {
  const AskPrayerTimes();
}

class AskMonthSpent extends QuickCommand {
  const AskMonthSpent();
}

class AskTasks extends QuickCommand {
  const AskTasks(this.day);
  final DateTime day;
}

/// «رتّبلي يومي» / «يومي عامل إزاي»
class AskDayOverview extends QuickCommand {
  const AskDayOverview();
}

class AskHelp extends QuickCommand {
  const AskHelp();
}

// ───────────────────────── أدوات ─────────────────────────

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

String _latinDigits(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _arabicDigits.indexOf(ch);
    final j = _persianDigits.indexOf(ch);
    b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : ch));
  }
  return b.toString().replaceAll('٫', '.').replaceAll('،', ',');
}

/// أرقام بالكلام (بعد التوحيد)
const _numberWords = {
  'واحد': 1,
  'واحده': 1,
  'اتنين': 2,
  'اثنين': 2,
  'تلاته': 3,
  'ثلاثه': 3,
  'اربعه': 4,
  'اربع': 4,
  'خمسه': 5,
  'خمس': 5,
  'سته': 6,
  'ست': 6,
  'سبعه': 7,
  'سبع': 7,
  'تمانيه': 8,
  'ثمانيه': 8,
  'تسعه': 9,
  'تسع': 9,
  'عشره': 10,
  'عشر': 10,
  'عشرين': 20,
  'تلاتين': 30,
  'اربعين': 40,
  'خمسين': 50,
  'ستين': 60,
  'سبعين': 70,
  'تمانين': 80,
  'تسعين': 90,
  'ميه': 100,
  'مية': 100,
  'ميتين': 200,
  'تلتميه': 300,
  'ربعميه': 400,
  'خمسميه': 500,
  'الف': 1000,
  'الفين': 2000,
};

/// أول رقم في الجملة (أرقام أو كلام)، مع «ألف»/«ك» بعده
double? firstNumber(String text) {
  final t = _latinDigits(text).replaceAll(',', '');
  final m = RegExp(r'(\d+(?:\.\d+)?)\s*(الف|ألف|k|ك(?=\s|$))?').firstMatch(t);
  if (m != null) {
    var v = double.parse(m.group(1)!);
    if (m.group(2) != null) v *= 1000;
    return v;
  }
  for (final w in normalizeArabic(t).split(RegExp(r'\s+'))) {
    final clean = w.startsWith('ب') && _numberWords.containsKey(w.substring(1))
        ? w.substring(1)
        : w;
    final v = _numberWords[clean];
    if (v != null) return v.toDouble();
  }
  return null;
}

bool _hasAny(String t, List<String> words) => words.any(t.contains);

/// كلمات التصنيف (بعد التوحيد) => رقم التصنيف
const _expenseKeywords = {
  'food': [
    'اكل',
    'غدا',
    'عشا',
    'فطار',
    'مطعم',
    'اكله',
    'خضار',
    'فاكهه',
    'لحمه',
    'فراخ',
    'عيش',
    'سندوتش',
    'كشري',
    'فول',
    'طعميه',
    'بيتزا',
    'سوبر ماركت',
    'بقاله',
  ],
  'transport': [
    'مواصلات',
    'بنزين',
    'عربيه',
    'تاكسي',
    'اوبر',
    'ميكروباص',
    'مترو',
    'توك توك',
    'جراج',
    'ركنه',
    'كريم',
  ],
  'bills': [
    'فاتوره',
    'كهربا',
    'غاز',
    'نت',
    'انترنت',
    'رصيد',
    'باقه',
    'تليفون',
    'اشتراك',
  ],
  'home': ['بيت', 'ايجار', 'منظفات', 'عفش', 'صيانه'],
  'health': ['دكتور', 'دوا', 'صيدليه', 'علاج', 'تحاليل', 'كشف', 'مستشفي'],
  'education': [
    'كورس',
    'كتاب',
    'كتب',
    'مدرسه',
    'دروس',
    'جامعه',
    'مصاريف دراسه',
  ],
  'fun': ['خروجه', 'سينما', 'قهوه', 'كافيه', 'فسحه', 'لعب', 'مصيف'],
  'clothes': ['لبس', 'هدوم', 'جزمه', 'قميص', 'بنطلون', 'فستان'],
  'charity': ['صدقه', 'زكاه', 'هديه', 'تبرع'],
};

String expenseCategoryFor(String normalized) {
  for (final e in _expenseKeywords.entries) {
    if (_hasAny(normalized, e.value)) return e.key;
  }
  return 'other';
}

String incomeCategoryFor(String normalized) {
  if (_hasAny(normalized, ['مرتب', 'قبضت', 'راتب'])) return 'salary';
  if (_hasAny(normalized, ['شغل حر', 'فريلانس', 'مشروع', 'عميل'])) {
    return 'freelance';
  }
  if (_hasAny(normalized, ['هديه', 'عيديه'])) return 'gift';
  return 'other_income';
}

const _prayerWords = {
  PrayerName.fajr: ['فجر', 'الصبح'],
  PrayerName.dhuhr: ['ضهر', 'ظهر'],
  PrayerName.asr: ['عصر'],
  PrayerName.maghrib: ['مغرب'],
  PrayerName.isha: ['عشا', 'عشاء'],
};

List<PrayerName> prayersIn(String normalized) => [
  for (final e in _prayerWords.entries)
    if (_hasAny(normalized, e.value)) e.key,
];

const _weekdays = {
  'سبت': DateTime.saturday,
  'حد': DateTime.sunday,
  'احد': DateTime.sunday,
  'اتنين': DateTime.monday,
  'اثنين': DateTime.monday,
  'تلات': DateTime.tuesday,
  'ثلاث': DateTime.tuesday,
  'اربع': DateTime.wednesday,
  'خميس': DateTime.thursday,
  'جمعه': DateTime.friday,
};

/// اليوم المقصود في الجملة (النهارده لو مفيش)
DateTime? dayIn(String normalized, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (normalized.contains('بعد بكره')) {
    return today.add(const Duration(days: 2));
  }
  if (normalized.contains('بكره') || normalized.contains('غدا ')) {
    return today.add(const Duration(days: 1));
  }
  if (_hasAny(normalized, ['النهارده', 'انهارده', 'اليوم'])) return today;
  final m = RegExp(
    r'(?:^|\s)(يوم\s+(?:ال)?|ال)(سبت|احد|حد|اتنين|اثنين|تلات|ثلاث|اربع|خميس|جمعه)(?:اء|ا)?(?=\s|$)',
  ).firstMatch(normalized);
  if (m != null) {
    final wd = _weekdays[m.group(2)]!;
    var diff = (wd - today.weekday) % 7;
    if (diff == 0) diff = 7;
    return today.add(Duration(days: diff));
  }
  return null;
}

/// الساعة المقصودة: «الساعة 5»، «5 ونص»، «8 الصبح»، «9 بالليل»
(int, int)? timeIn(String normalized) {
  final t = _latinDigits(normalized);
  final m = RegExp(
    r'(?:الساعه|ساعه)\s*(\d{1,2})(?::(\d{2}))?|(\d{1,2})(?::(\d{2}))?\s*(?:الصبح|صباحا|بالليل|بليل|مساء|العصر|بعد الضهر|ونص|وربع|الا ربع|ص(?=\s|$)|م(?=\s|$))',
  ).firstMatch(t);
  if (m == null) return null;
  var h = int.parse(m.group(1) ?? m.group(3)!);
  var min = int.tryParse(m.group(2) ?? m.group(4) ?? '') ?? 0;
  if (h > 23) return null;
  if (t.contains('ونص')) min = 30;
  if (t.contains('وربع')) min = 15;
  if (t.contains('الا ربع')) {
    min = 45;
    h = h == 0 ? 23 : h - 1;
  }
  final morning =
      _hasAny(t, ['الصبح', 'صباحا']) || RegExp(r'\d\s*ص(\s|$)').hasMatch(t);
  final evening =
      _hasAny(t, ['بالليل', 'بليل', 'مساء', 'العصر', 'بعد الضهر']) ||
      RegExp(r'\d\s*م(\s|$)').hasMatch(t);
  if (h <= 12) {
    if (evening && h < 12) {
      h += 12;
    } else if (!morning && !evening && h >= 1 && h <= 6) {
      // «الساعة 5» من غير تحديد غالبًا العصر
      h += 12;
    } else if (morning && h == 12) {
      h = 0;
    }
  }
  return (h, min);
}

/// بيشيل كلمات الأمر والوقت عشان يفضل عنوان المهمة
String _taskTitle(String original) {
  var t = _latinDigits(original);
  final remove = [
    RegExp(
      r'^\s*(فكّرني|فكرني|ذكّرني|ذكرني|افكرك|فكّرنى|فكرنى|ضيف مهم[هة]|ضيف|سجّل مهم[هة]|سجل مهم[هة]|مهم[هة]|عايز|عاوز|لازم|محتاج)\s*',
    ),
    RegExp(r'^\s*(إني|اني|إن|ان|أ?ن)\s+'),
    RegExp(r'\s*(بعد بكر[هة]|بكر[هة]|النهارد[هة]|انهارد[هة]|اليوم)\s*'),
    RegExp(
      r'(^|\s)(يوم\s+(ال)?|ال)(سبت|حد|أحد|احد|اتنين|إثنين|اثنين|تلات|ثلاثاء|أربع|اربع|أربعاء|اربعاء|خميس|جمع[هة])(?=\s|$)',
    ),
    RegExp(
      r'\s*(الساع[هة]|ساع[هة])?\s*\d{1,2}(:\d{2})?(\s*(الصبح|صباحًا|صباحا|بالليل|بليل|مساءً|مساء|العصر|بعد الضهر|ونص|وربع|إلا ربع|الا ربع|ص|م))*\s*$',
    ),
    RegExp(r'\s*(الساع[هة]|ساع[هة])\s*\d{1,2}(:\d{2})?\s*'),
  ];
  for (var i = 0; i < 3; i++) {
    for (final r in remove) {
      t = t.replaceAll(r, ' ');
    }
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll(RegExp(r'^(إني|اني|إن|ان)\s+'), '');
  return t;
}

String _afterAmount(String original) {
  final t = _latinDigits(original);
  final m = RegExp(
    r'\d+(?:\.\d+)?\s*(?:جنيه|ج|الف|ألف)?\s*(?:في|على|علي|ل|عشان)?\s*(.*)$',
  ).firstMatch(t);
  var note = (m?.group(1) ?? '').trim();
  if (note.isEmpty) {
    // «اشتريت خضار ب 80»
    note = t
        .replaceAll(RegExp(r'^\s*(صرفت|دفعت|اشتريت|جبت)\s*'), '')
        .replaceAll(RegExp(r'\s*ب?\s*\d+(?:\.\d+)?\s*(جنيه|ج)?\s*$'), '')
        .trim();
  }
  return note;
}

// ───────────────────────── الفهم ─────────────────────────

/// بيرجّع الأمر المفهوم أو null لو الجملة مش مفهومة
QuickCommand? parseCommand(String input, DateTime now) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  final n = normalizeArabic(_latinDigits(raw))
      .replaceAll(RegExp(r'[؟?!.]'), ' ')
      .trim();

  // مساعدة
  if (_hasAny(n, [
    'مساعده',
    'بتعرف تعمل',
    'تقدر تعمل',
    'اوامر',
    'ازاي استخدمك',
  ])) {
    return const AskHelp();
  }

  if (_hasAny(n, [
    'رتبلي يومي',
    'رتب يومي',
    'يومي عامل',
    'خطه اليوم',
    'ملخص يومي',
    'ملخص النهارده',
  ])) {
    return const AskDayOverview();
  }

  // الأسئلة
  final isQuestion =
      _hasAny(n, ['كام', 'قد ايه', 'امتي', 'ايه', 'فين', 'اد ايه']) ||
      raw.contains('؟') ||
      raw.contains('?');
  if (isQuestion) {
    if (_hasAny(n, ['مواقيت', 'مواعيد الصلاه', 'مواعيد الصلوات'])) {
      return const AskPrayerTimes();
    }
    final ps = prayersIn(n);
    if (_hasAny(n, [
          'الصلاه الجايه',
          'فاضل',
          'باقي',
          'امتي',
          'الاذان',
          'اذان',
        ]) &&
        (ps.isNotEmpty || n.contains('صلاه') || n.contains('اذان'))) {
      return AskNextPrayer(ps.isEmpty ? null : ps.first);
    }
    if (_hasAny(n, ['صرفت', 'مصروف', 'المصاريف', 'فلوس']) &&
        _hasAny(n, ['كام', 'قد ايه', 'اد ايه'])) {
      return const AskMonthSpent();
    }
    if (_hasAny(n, ['مهام', 'مهامي', 'عندي ايه', 'ورايا ايه', 'ورايا'])) {
      return AskTasks(dayIn(n, now) ?? DateTime(now.year, now.month, now.day));
    }
  }

  // مصروف
  if (RegExp(r'^(انا\s+)?(صرفت|دفعت|اشتريت|جبت)').hasMatch(n)) {
    final amount = firstNumber(raw);
    if (amount != null && amount > 0) {
      return AddExpense(amount, expenseCategoryFor(n), _afterAmount(raw));
    }
  }

  // دخل
  if (RegExp(r'^(انا\s+)?(قبضت|استلمت|جالي|جاتلي|دخلي|كسبت|خدت)').hasMatch(n)) {
    final amount = firstNumber(raw);
    if (amount != null && amount > 0) {
      return AddIncome(amount, incomeCategoryFor(n), _afterAmount(raw));
    }
  }

  // الصلاة
  if (RegExp(r'^(انا\s+)?(صليت|صلّيت)').hasMatch(n)) {
    final mosque = _hasAny(n, ['جامع', 'مسجد', 'جماعه']);
    if (_hasAny(n, ['كله', 'كلهم', 'الخمس', 'كل الصلوات'])) {
      return LogPrayers(PrayerName.values, mosque: mosque);
    }
    final ps = prayersIn(n);
    if (ps.isNotEmpty) return LogPrayers(ps, mosque: mosque);
  }

  // القرآن
  if (RegExp(r'^(انا\s+)?(قريت|قرات|خلصت)').hasMatch(n) &&
      _hasAny(n, ['صفح', 'جزء', 'قران', 'ورد'])) {
    if (n.contains('جزء')) {
      final k = firstNumber(raw)?.toInt() ?? 1;
      return LogQuran(k * 20);
    }
    final p = firstNumber(raw)?.toInt();
    if (p != null && p > 0 && p <= 604) return LogQuran(p);
  }

  // مهمة
  if (RegExp(r'^(فكرني|فكّرني|ذكرني|ضيف|سجل مهمه|مهمه|عايز|عاوز|لازم|محتاج)')
      .hasMatch(n)) {
    final title = _taskTitle(raw);
    if (title.isNotEmpty && !RegExp(r'^\d+$').hasMatch(title)) {
      final day = dayIn(n, now);
      var time = timeIn(n);
      // «بكرة 5»: رقم لوحده في الآخر بعد يوم
      if (time == null && day != null) {
        final m = RegExp(r'\s(\d{1,2})(?::(\d{2}))?\s*$').firstMatch(n);
        final h = int.tryParse(m?.group(1) ?? '');
        if (h != null && h <= 23) {
          time = timeIn(
            'الساعه $h${m!.group(2) == null ? '' : ':${m.group(2)}'}',
          );
        }
      }
      DateTime? remindAt;
      var due = day;
      if (time != null) {
        final base = day ?? DateTime(now.year, now.month, now.day);
        remindAt = DateTime(base.year, base.month, base.day, time.$1, time.$2);
        // لو الوقت عدّى النهارده ومفيش يوم محدد => بكرة
        if (day == null && !remindAt.isAfter(now)) {
          remindAt = remindAt.add(const Duration(days: 1));
        }
        due = DateTime(remindAt.year, remindAt.month, remindAt.day);
      }
      final isReminder = n.startsWith('فكرني') || n.startsWith('ذكرني');
      return AddTaskCommand(
        title,
        dueDate:
            due ?? (isReminder ? DateTime(now.year, now.month, now.day) : null),
        remindAt: remindAt,
      );
    }
  }

  // عادة أو مهمة خلصت
  final done = RegExp(r'^(انا\s+)?(عملت|خلصت|خلّصت|انجزت)\s+(.+)$')
      .firstMatch(n);
  if (done != null) {
    final name = done
        .group(3)!
        .replaceAll(RegExp(r'^(مهمه|عاده)\s+'), '')
        .trim();
    if (name.isNotEmpty) return MarkDone(name);
  }

  return null;
}
