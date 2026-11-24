import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/notification_actions.dart';
import '../../core/notifications.dart';
import '../worship/prayer_service.dart';
import '../worship/prayer_settings.dart';
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
    this.weeklyReview = true,
    this.prePrayerMinutes = 0,
    this.adhkar = true,
    this.kahf = true,
    this.nightSummary = true,
  });
  final bool morningSummary;
  final int morningHour;
  final bool fastingMonThu;
  final bool fastingWhiteDays;

  /// تذكير المراجعة الأسبوعية كل جمعة 8 بالليل
  final bool weeklyReview;

  /// تنبيه قبل الصلاة بكام دقيقة (0 = مقفول)
  final int prePrayerMinutes;

  /// أذكار الصباح (بعد الفجر بنص ساعة) والمساء (بعد العصر بنص ساعة)
  final bool adhkar;

  /// سورة الكهف يوم الجمعة الصبح
  final bool kahf;

  /// ملخص اليوم الساعة 9:30 بالليل
  final bool nightSummary;
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
      weeklyReview: p.getBool('rem_weekly_review') ?? true,
      prePrayerMinutes: p.getInt('rem_pre_prayer') ?? 0,
      adhkar: p.getBool('rem_adhkar') ?? true,
      kahf: p.getBool('rem_kahf') ?? true,
      nightSummary: p.getBool('rem_night') ?? true,
    );
  }

  Future<void> update({
    bool? morning,
    int? hour,
    bool? monThu,
    bool? white,
    bool? review,
    int? prePrayer,
    bool? adhkar,
    bool? kahf,
    bool? night,
  }) async {
    final p = ref.read(sharedPrefsProvider);
    if (morning != null) await p.setBool('rem_morning', morning);
    if (hour != null) await p.setInt('rem_morning_hour', hour);
    if (monThu != null) await p.setBool('rem_fast_monthu', monThu);
    if (white != null) await p.setBool('rem_fast_white', white);
    if (review != null) await p.setBool('rem_weekly_review', review);
    if (prePrayer != null) await p.setInt('rem_pre_prayer', prePrayer);
    if (adhkar != null) await p.setBool('rem_adhkar', adhkar);
    if (kahf != null) await p.setBool('rem_kahf', kahf);
    if (night != null) await p.setBool('rem_night', night);
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

/// نص ملخص الليل من بيانات النهارده
String nightSummaryText({
  required DateTime day,
  required List<HayatiTask> tasks,
  required List<Habit> habits,
  required int prayersLogged,
  required double spentToday,
}) {
  final key = HayatiDates.dayKey(day);
  final left = tasks.where((t) => !t.done && t.dueDate == key).length;
  final doneToday = tasks.where((t) => t.done && t.dueDate == key).length;
  final todayHabits = habits.where((h) => h.isScheduled(day)).toList();
  final habitsDone = todayHabits.where((h) => h.isDoneOn(day)).length;
  final parts = <String>[
    if (doneToday > 0) '✅ خلّصت $doneToday',
    if (left > 0) 'فاضل $left لبكرة',
    '🕌 $prayersLogged/5',
    if (todayHabits.isNotEmpty) '🔥 $habitsDone/${todayHabits.length} عادات',
    '💸 ${formatMoney(spentToday)}',
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
  static const _reviewId = 5000050;

  /// الجمعة الجاية الساعة 8 بالليل (أو النهارده لو لسه مجاش الميعاد)
  static DateTime nextReviewAt(DateTime now) {
    var at = DateTime(now.year, now.month, now.day, 20);
    while (at.weekday != DateTime.friday || !at.isAfter(now)) {
      at = DateTime(at.year, at.month, at.day + 1, 20);
    }
    return at;
  }

  static const _prePrayerBase = 5000200;
  static const _adhkarBase = 5000300;
  static const _kahfId = 5000060;
  static const _nightId = 5000070;

  /// قبل الصلاة + الأذكار: مربوطين بمواقيت الأيام الجاية
  static Future<void> syncPrayerLinked(
    ReminderSettings settings,
    PrayerSettings prayer,
  ) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    for (var i = 0; i < 20; i++) {
      await n.plugin.cancel(id: _prePrayerBase + i);
    }
    for (var i = 0; i < 8; i++) {
      await n.plugin.cancel(id: _adhkarBase + i);
    }
    final now = DateTime.now();
    final mode = await n.scheduleMode();
    Future<void> at(
      int id,
      DateTime when,
      NotificationDetails d,
      String title,
      String body, [
      String? payload,
    ]) async {
      if (!when.isAfter(now)) return;
      try {
        await n.plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          notificationDetails: d,
          androidScheduleMode: mode,
          title: title,
          body: body,
          payload: payload,
        );
      } catch (e) {
        debugPrint('prayer-linked reminder failed: $e');
      }
    }

    final pre = AppNotifications.channel(
      'pre_prayer_v2',
      'قبل الصلاة',
      'تنبيه قبل دخول وقت الصلاة',
    );
    final adhkarCh = AppNotifications.channel(
      'adhkar_v2',
      'الأذكار',
      'تذكير بأذكار الصباح والمساء',
    );
    for (var d = 0; d < 4; d++) {
      final times = computePrayerTimes(prayer, now.add(Duration(days: d)));
      if (settings.prePrayerMinutes > 0) {
        for (final p in PrayerName.values) {
          final when = times[p].subtract(
            Duration(minutes: settings.prePrayerMinutes),
          );
          await at(
            _prePrayerBase + d * 5 + p.index,
            when,
            pre,
            '🕌 فاضل ${settings.prePrayerMinutes} دقايق على ${p.ar}',
            'اتوضّى واستعد للصلاة ${formatPrayerTime(times[p])}',
          );
        }
      }
      if (settings.adhkar) {
        await at(
          _adhkarBase + d * 2,
          times[PrayerName.fajr].add(const Duration(minutes: 30)),
          adhkarCh,
          '☀️ أذكار الصباح',
          'دقيقتين تبدأ بيهم يومك',
          NotificationActions.openPayload('/worship/adhkar/morning'),
        );
        await at(
          _adhkarBase + d * 2 + 1,
          times[PrayerName.asr].add(const Duration(minutes: 30)),
          adhkarCh,
          '🌙 أذكار المساء',
          'متنساش أذكار المساء',
          NotificationActions.openPayload('/worship/adhkar/evening'),
        );
      }
    }
  }

  /// سورة الكهف كل جمعة الساعة 10 الصبح
  static Future<void> syncKahf(ReminderSettings settings) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    await n.plugin.cancel(id: _kahfId);
    if (!settings.kahf) return;
    var at = DateTime.now();
    at = DateTime(at.year, at.month, at.day, 10);
    while (at.weekday != DateTime.friday || !at.isAfter(DateTime.now())) {
      at = DateTime(at.year, at.month, at.day + 1, 10);
    }
    try {
      await n.plugin.zonedSchedule(
        id: _kahfId,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: AppNotifications.channel(
          'kahf_v2',
          'سورة الكهف',
          'تذكير بقراءة سورة الكهف يوم الجمعة',
        ),
        androidScheduleMode: await n.scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        title: '📖 جمعة مباركة',
        body: 'متنساش سورة الكهف النهارده',
        payload: NotificationActions.openPayload('/worship/quran'),
      );
    } catch (e) {
      debugPrint('kahf reminder failed: $e');
    }
  }

  /// ملخص الليل 9:30 (بيتحدث كل ما البيانات تتغير)
  static Future<void> syncNight(ReminderSettings settings, String text) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    await n.plugin.cancel(id: _nightId);
    if (!settings.nightSummary) return;
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, 21, 30);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    try {
      await n.plugin.zonedSchedule(
        id: _nightId,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: AppNotifications.channel(
          'night_v2',
          'ملخص الليل',
          'ملخص يومك بالليل',
        ),
        androidScheduleMode: await n.scheduleMode(),
        title: '🌙 يومك في سطر',
        body: text,
        payload: NotificationActions.openPayload('/today'),
      );
    } catch (e) {
      debugPrint('night summary failed: $e');
    }
  }

  static Future<void> syncWeeklyReview(ReminderSettings settings) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    await n.plugin.cancel(id: _reviewId);
    if (!settings.weeklyReview) return;
    try {
      await n.plugin.zonedSchedule(
        id: _reviewId,
        scheduledDate: tz.TZDateTime.from(
          nextReviewAt(DateTime.now()),
          tz.local,
        ),
        notificationDetails: AppNotifications.channel(
          'weekly_review_v2',
          'المراجعة الأسبوعية',
          'تذكير كل جمعة تراجع أسبوعك',
        ),
        androidScheduleMode: await n.scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        title: '📝 وقت مراجعة الأسبوع',
        body: '5 دقايق تشوف فيهم أسبوعك وتخطط للجاي',
      );
    } catch (e) {
      debugPrint('weekly review reminder failed: $e');
    }
  }

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
          'morning_v2',
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
      'fasting_v2',
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
