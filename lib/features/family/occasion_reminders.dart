import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/notifications.dart';
import 'family_models.dart';

/// تذكير سنوي قبل كل مناسبة، الساعة 9 الصبح
class OccasionReminders {
  static const _base = 4000000;

  static Future<void> sync(List<Occasion> list) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    final details = AppNotifications.channel(
      'occasions',
      'المناسبات',
      'تذكير بأعياد الميلاد والمناسبات',
    );
    final mode = await n.scheduleMode();
    final wanted = <int>{};
    final now = DateTime.now();

    for (final o in list) {
      final id = AppNotifications.idFor('occasion', o.id, _base);
      wanted.add(id);
      var at = o.nextDate(now).subtract(Duration(days: o.remindDaysBefore));
      at = DateTime(at.year, at.month, at.day, 9);
      if (!at.isAfter(now)) {
        final next = DateTime(
          o.nextDate(now).year + 1,
          o.month,
          o.day,
        ).subtract(Duration(days: o.remindDaysBefore));
        at = DateTime(next.year, next.month, next.day, 9);
      }
      final when = o.remindDaysBefore == 0
          ? 'النهارده'
          : o.remindDaysBefore == 1
          ? 'بكرة'
          : 'بعد ${o.remindDaysBefore} أيام';
      try {
        await n.plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: details,
          androidScheduleMode: mode,
          title: '${o.type.emoji} ${o.title}',
          body: '$when • متنساش تجهّز وتكلّمهم 💚',
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      } catch (e) {
        debugPrint('occasion reminder failed: $e');
      }
    }
    final pending = await n.plugin.pendingNotificationRequests();
    for (final p in pending) {
      final inRange = p.id >= _base && p.id < _base + 0x80000;
      if (inRange && !wanted.contains(p.id)) await n.plugin.cancel(id: p.id);
    }
  }
}
