import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/notification_actions.dart';
import '../../core/notifications.dart';

import 'prayer_service.dart';
import 'prayer_settings.dart';

/// إشعارات الأذان: بنجدول الأيام الجاية كل ما التطبيق يفتح أو الإعدادات تتغير
class AdhanNotifications {
  AdhanNotifications._();
  static final instance = AdhanNotifications._();

  AppNotifications get _n => AppNotifications.instance;
  FlutterLocalNotificationsPlugin get _plugin => _n.plugin;
  static const _daysAhead = 4;
  static const _baseId = 1000;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'adhan',
      'الأذان',
      channelDescription: 'تنبيه بدخول وقت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: NotificationActions.prayerButtons,
    ),
  );

  Future<bool> requestPermissions() => _n.requestPermissions();

  Future<void> reschedule(PrayerSettings settings) async {
    await _n.init();
    if (!_n.ready) return;
    for (var i = 0; i < _daysAhead * PrayerName.values.length; i++) {
      await _plugin.cancel(id: _baseId + i);
    }
    if (!settings.adhanNotifications) return;

    final mode = await _n.scheduleMode();
    final now = DateTime.now();
    var id = _baseId;
    for (var d = 0; d < _daysAhead; d++) {
      final day = computePrayerTimes(settings, now.add(Duration(days: d)));
      for (final p in PrayerName.values) {
        final time = day[p];
        final thisId = id++;
        if (!time.isAfter(now)) continue;
        try {
          await _plugin.zonedSchedule(
            id: thisId,
            scheduledDate: tz.TZDateTime.from(time, tz.local),
            notificationDetails: _details,
            androidScheduleMode: mode,
            title: 'حان الآن موعد صلاة ${p.ar}',
            body: '${formatPrayerTime(time)} • ${settings.placeLabel}',
            payload: NotificationActions.prayerPayload(p.name, time),
          );
        } catch (e) {
          debugPrint('schedule failed: $e');
        }
      }
    }
  }
}
