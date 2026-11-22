import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_service.dart';
import 'prayer_settings.dart';

/// إشعارات الأذان: بنجدول الأيام الجاية كل ما التطبيق يفتح أو الإعدادات تتغير
class AdhanNotifications {
  AdhanNotifications._();
  static final instance = AdhanNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
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
    ),
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// يطلب إذن الإشعارات (أندرويد 13+) والمنبّهات الدقيقة (أندرويد 14+)
  Future<bool> requestPermissions() async {
    await init();
    final granted = await _android?.requestNotificationsPermission() ?? false;
    if (await _android?.canScheduleExactNotifications() == false) {
      await _android?.requestExactAlarmsPermission();
    }
    return granted;
  }

  Future<void> reschedule(PrayerSettings settings) async {
    await init();
    if (!_ready) return;
    for (var i = 0; i < _daysAhead * PrayerName.values.length; i++) {
      await _plugin.cancel(id: _baseId + i);
    }
    if (!settings.adhanNotifications) return;

    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
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
          );
        } catch (e) {
          debugPrint('schedule failed: $e');
        }
      }
    }
  }
}
