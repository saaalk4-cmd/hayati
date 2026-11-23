import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/notifications.dart';
import '../../core/utils/date_utils.dart';
import '../../data/session.dart';
import '../../data/task.dart';
import '../habits/habit.dart';
import '../money/money_models.dart';

/// إعدادات التنبيهات الذكية (على الجهاز)
class ReminderSettings {
  const ReminderSettings({
    this.morningSummary = true,
    this.morningHour = 7,
    this.fastingMonThu = true,
    this.fastingWhiteDays = true,
  });
  final bool morningSummary;
  final int morningHour;
  final bool fastingMonThu;
  final bool fastingWhiteDays;
}

class ReminderSettingsController extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() {
    final p = ref.read(sharedPrefsProvider);
    return ReminderSettings(
      morningSummary: p.getBool('rem_morning') ?? true,
      morningHour: p.getInt('rem_morning_hour') ?? 7,
      fastingMonThu: p.getBool('rem_fast_monthu') ?? true,
      fastingWhiteDays: p.getBool('rem_fast_white') ?? true,
    );
  }

  Future<void> update({
    bool? morning,
    int? hour,
    bool? monThu,
    bool? white,
  }) async {
    final p = ref.read(sharedPrefsProvider);
    if (morning != null) await p.setBool('rem_morning', morning);
    if (hour != null) await p.setInt('rem_morning_hour', hour);
    if (monThu != null) await p.setBool('rem_fast_monthu', monThu);
    if (white != null) await p.setBool('rem_fast_white', white);
    state = build();
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsController, ReminderSettings>(
      ReminderSettingsController.new,
    );

/// نص ملخص الصبح من البيانات الحالية
String morningSummaryText({
  required DateTime day,
  required List<HayatiTask> tasks,
  required List<Habit> habits,
  required double spentMonth,
  required double? budget,
}) {
  final key = HayatiDates.dayKey(day);
  final due = tasks
      .where(
        (t) => !t.done && t.dueDate != null && t.dueDate!.compareTo(key) <= 0,
      )
      .length;
  final todayHabits = habits.where((h) => h.isScheduled(day)).toList();
  Habit? best;
  for (final h in todayHabits) {
    if (best == null || h.streak(day) > best.streak(day)) best = h;
  }
  final parts = <String>[
    due == 0
        ? 'مفيش مهام متأخرة 👌'
        : 'عندك $due ${due == 1 ? 'مهمة' : 'مهام'} النهارده',
    if (todayHabits.isNotEmpty) '${todayHabits.length} عادات',
    if (best != null && best.streak(day) > 1)
      '🔥 ${best.emoji} ${best.streak(day)} يوم',
    if (budget != null) 'فاضل ${formatMoney(budget - spentMonth)} من الميزانية',
  ];
  return parts.join(' • ');
}

/// أيام الصيام المستحبة الجاية (الاتنين والخميس، والأيام البيض 13-15 هجري)
/// بترجع: يوم الصيام والسبب
List<(DateTime, String)> upcomingFastingDays(
  DateTime from, {
  required bool monThu,
  required bool whiteDays,
  bool special = true,
  int days = 21,
}) {
  final out = <(DateTime, String)>[];
  final start = DateTime(from.year, from.month, from.day);
  for (var i = 1; i <= days; i++) {
    final d = start.add(Duration(days: i));
    final h = HijriCalendar.fromDate(
      d.add(Duration(days: HayatiDates.hijriAdjust)),
    );
    // رمضان (9): الصيام فرض، ويوم العيد (1 شوال) و10-13 ذو الحجة ممنوع فيهم الصيام
    if (h.hMonth == 9) continue;
    // صيام عرفة وتاسوعاء وعاشوراء (أولوية على الاتنين والخميس)
    if (special &&
        ((h.hMonth == 12 && h.hDay == 9) ||
            (h.hMonth == 1 && (h.hDay == 9 || h.hDay == 10)))) {
      final name = h.hMonth == 12
          ? 'يوم عرفة'
          : (h.hDay == 9 ? 'يوم تاسوعاء' : 'يوم عاشوراء');
      out.add((d, 'بكرة $name — صيام مستحب'));
      continue;
    }
    if (h.hMonth == 10 && h.hDay == 1) continue;
    if (h.hMonth == 12 && h.hDay >= 10 && h.hDay <= 13) continue;
    if (whiteDays && h.hDay == 13) {
      out.add((d, 'الأيام البيض بتبدأ بكرة (13 و14 و15 هجري)'));
    } else if (monThu &&
        (d.weekday == DateTime.monday || d.weekday == DateTime.thursday)) {
      out.add((
        d,
        'بكرة ${d.weekday == DateTime.monday ? 'الاتنين' : 'الخميس'} — تحب تصوم؟',
      ));
    }
  }
  return out;
}

class SmartReminders {
  static const _morningId = 5000000;
  static const _fastBase = 5000100;

  static Future<void> syncMorning({
    required ReminderSettings settings,
    required List<HayatiTask> tasks,
    required List<Habit> habits,
    required double spentMonth,
    required double? budget,
  }) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    await n.plugin.cancel(id: _morningId);
    if (!settings.morningSummary) return;
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, settings.morningHour);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    try {
      await n.plugin.zonedSchedule(
        id: _morningId,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: AppNotifications.channel(
          'morning',
          'ملخص الصبح',
          'ملخص يومك كل صباح',
        ),
        androidScheduleMode: await n.scheduleMode(),
        title: '☀️ صباح الخير، ده يومك',
        body: morningSummaryText(
          day: at,
          tasks: tasks,
          habits: habits,
          spentMonth: spentMonth,
          budget: budget,
        ),
      );
    } catch (e) {
      debugPrint('morning summary failed: $e');
    }
  }

  static Future<void> syncFasting(ReminderSettings settings) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    for (var i = 0; i < 20; i++) {
      await n.plugin.cancel(id: _fastBase + i);
    }
    final list = upcomingFastingDays(
      DateTime.now(),
      monThu: settings.fastingMonThu,
      whiteDays: settings.fastingWhiteDays,
    );
    final details = AppNotifications.channel(
      'fasting',
      'تذكير الصيام',
      'تذكير بصيام الاتنين والخميس والأيام البيض',
    );
    final mode = await n.scheduleMode();
    var i = 0;
    for (final (day, text) in list.take(20)) {
      final eve = day.subtract(const Duration(days: 1));
      final at = DateTime(eve.year, eve.month, eve.day, 21);
      if (!at.isAfter(DateTime.now())) continue;
      try {
        await n.plugin.zonedSchedule(
          id: _fastBase + i++,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: details,
          androidScheduleMode: mode,
          title: '🌙 تذكير بالصيام',
          body: '$text • متنساش نية الصيام والسحور',
        );
      } catch (e) {
        debugPrint('fasting reminder failed: $e');
      }
    }
  }
}
