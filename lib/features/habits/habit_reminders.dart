import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/notifications.dart';
import 'habit.dart';

/// تذكير يومي/أسبوعي لكل عادة ليها وقت تذكير
class HabitReminders {
  static const _base = 2000000;

  static int _id(String habitId, int weekday) =>
      AppNotifications.idFor('habit', '$habitId:$weekday', _base);

  static Future<void> sync(List<Habit> habits) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    final wanted = <int>{};
    final details = AppNotifications.channel(
      'habits',
      'تذكير العادات',
      'تذكير بعاداتك اليومية',
    );
    final mode = await n.scheduleMode();

    for (final h in habits) {
      final r = h.reminder;
      if (r == null) continue;
      final parts = r.split(':');
      final hour = int.tryParse(parts.first) ?? 9;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      for (final wd in h.weekdays) {
        final id = _id(h.id, wd);
        wanted.add(id);
        try {
          await n.plugin.zonedSchedule(
            id: id,
            scheduledDate: _next(wd, hour, minute),
            notificationDetails: details,
            androidScheduleMode: mode,
            title: '${h.emoji} ${h.title}',
            body: 'متنساش عادتك النهارده 💪',
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e) {
          debugPrint('habit reminder failed: $e');
        }
      }
    }
    // إلغاء تذكيرات العادات اللي اتمسحت أو اتغيرت
    final pending = await n.plugin.pendingNotificationRequests();
    for (final p in pending) {
      final inRange = p.id >= _base && p.id < _base + 0x80000;
      if (inRange && !wanted.contains(p.id)) await n.plugin.cancel(id: p.id);
    }
  }

  static tz.TZDateTime _next(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (t.weekday != weekday || !t.isAfter(now)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }
}
