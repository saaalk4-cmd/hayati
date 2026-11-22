import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/notifications.dart';
import '../../data/task.dart';

/// تذكيرات المهام اللي ليها وقت
class TaskReminders {
  static const _base = 3000000;

  static Future<void> sync(List<HayatiTask> tasks) async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready) return;
    final now = DateTime.now();
    final details = AppNotifications.channel(
      'tasks',
      'تذكير المهام',
      'تذكير بمواعيد مهامك',
    );
    final mode = await n.scheduleMode();
    final wanted = <int>{};

    for (final t in tasks) {
      final at = t.remindAt;
      if (t.done || at == null || !at.isAfter(now)) continue;
      final id = AppNotifications.idFor('task', t.id, _base);
      wanted.add(id);
      try {
        await n.plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: details,
          androidScheduleMode: mode,
          title: '⏰ ${t.title}',
          body: t.notes ?? 'معاد المهمة دي دلوقتي',
        );
      } catch (e) {
        debugPrint('task reminder failed: $e');
      }
    }
    final pending = await n.plugin.pendingNotificationRequests();
    for (final p in pending) {
      final inRange = p.id >= _base && p.id < _base + 0x80000;
      if (inRange && !wanted.contains(p.id)) await n.plugin.cancel(id: p.id);
    }
  }
}
