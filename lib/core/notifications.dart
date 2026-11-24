import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_actions.dart';

/// خدمة الإشعارات المشتركة (الأذان، العادات، تذكير المهام)
class AppNotifications {
  AppNotifications._();
  static final instance = AppNotifications._();

  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;
  Future<void>? _initFuture;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: handleNotificationAction,
        onDidReceiveBackgroundNotificationResponse:
            notificationActionBackground,
      );
      ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> requestPermissions() async {
    await init();
    final granted = await android?.requestNotificationsPermission() ?? false;
    if (await android?.canScheduleExactNotifications() == false) {
      await android?.requestExactAlarmsPermission();
    }
    return granted;
  }

  Future<AndroidScheduleMode> scheduleMode() async {
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// صوت إشعار حياتي (android/app/src/main/res/raw/hayati_chime.wav)
  static const chime = RawResourceAndroidNotificationSound('hayati_chime');

  /// القنوات بصوت حياتي ليها «_v2» في الآخر (أندرويد مبيغيّرش صوت قناة موجودة)
  static NotificationDetails channel(
    String id,
    String name,
    String desc, {
    List<AndroidNotificationAction>? actions,
    bool chimeSound = true,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      id,
      name,
      channelDescription: desc,
      importance: Importance.high,
      priority: Priority.high,
      sound: chimeSound ? chime : null,
      actions: actions,
    ),
  );

  /// معرّف رقمي ثابت من نص (للعادات والمهام)
  static int idFor(String prefix, String key, int base) =>
      base + (('$prefix:$key').hashCode & 0x7FFFF);
}
