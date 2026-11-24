import 'dart:convert';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/date_utils.dart';
import '../data/session.dart';
import '../data/tasks_repository.dart';
import '../data/user_store.dart';
import '../features/habits/habits_repository.dart';
import 'config/app_config.dart';
import 'notifications.dart';

/// أزرار جوه الإشعار: «خلصت» و«بعد 10 دقايق» و«صليت» و«عملتها»
class NotificationActions {
  NotificationActions._();

  static const done = 'done';
  static const snooze = 'snooze';
  static const prayed = 'prayed';

  static String taskPayload(String id) => jsonEncode({'t': 'task', 'id': id});
  static String habitPayload(String id) => jsonEncode({'t': 'habit', 'id': id});
  static String prayerPayload(String prayer, DateTime day) =>
      jsonEncode({'t': 'prayer', 'p': prayer, 'd': HayatiDates.dayKey(day)});

  static const taskButtons = [
    AndroidNotificationAction(done, '✅ خلصت', cancelNotification: true),
    AndroidNotificationAction(
      snooze,
      '⏰ بعد 10 دقايق',
      cancelNotification: true,
    ),
  ];
  static const habitButtons = [
    AndroidNotificationAction(done, '🔥 عملتها', cancelNotification: true),
  ];
  static const prayerButtons = [
    AndroidNotificationAction(prayed, '🕌 صليت', cancelNotification: true),
  ];

  /// حاوية التطبيق لو شغال (عشان الشاشات تتحدث على طول)
  static ProviderContainer? appContainer;
}

/// بيتنادى من أندرويد لما التطبيق مقفول أو في الخلفية
@pragma('vm:entry-point')
Future<void> notificationActionBackground(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  await handleNotificationAction(r);
}

Future<void> handleNotificationAction(NotificationResponse r) async {
  final action = r.actionId;
  if (action == null || action.isEmpty) return; // دوسة عادية: بتفتح التطبيق بس
  final Map<String, dynamic> p;
  try {
    p = (jsonDecode(r.payload ?? '{}') as Map).cast<String, dynamic>();
  } catch (_) {
    return;
  }

  var own = false;
  var container = NotificationActions.appContainer;
  if (container == null) {
    // التطبيق مقفول: نجهّز نفس طبقة البيانات اللي التطبيق بيستخدمها
    final prefs = await SharedPreferences.getInstance();
    var firebase = false;
    if (AppConfig.hasFirebase) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: AppConfig.firebaseOptions);
        }
        firebase = true;
        if (!(prefs.getBool('guest_mode') ?? false)) {
          // نستنى الحساب المحفوظ يتحمّل عشان منكتبش في المكان الغلط
          await FirebaseAuth.instance.authStateChanges().first.timeout(
            const Duration(seconds: 8),
          );
        }
      } catch (e) {
        debugPrint('notification action firebase: $e');
      }
    }
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        firebaseReadyProvider.overrideWithValue(firebase),
      ],
    );
    own = true;
  }

  try {
    final now = DateTime.now();
    switch ((p['t'], action)) {
      case ('task', NotificationActions.done):
        final repo = container.read(tasksRepositoryProvider);
        final tasks = await repo.watch().first;
        final t = tasks.where((x) => x.id == p['id']).firstOrNull;
        if (t != null && !t.done) await repo.toggle(t);
      case ('task', NotificationActions.snooze):
        await _snooze(r, const Duration(minutes: 10));
      case ('habit', NotificationActions.done):
        final repo = container.read(habitsRepositoryProvider);
        final habits = await repo.watch().first;
        final h = habits.where((x) => x.id == p['id']).firstOrNull;
        if (h != null && !h.isDoneOn(now)) await repo.setDone(h, now, true);
      case ('prayer', NotificationActions.prayed):
        final day = (p['d'] as String?) ?? HayatiDates.dayKey(now);
        await container.read(userStoreProvider).merge('prayers', day, {
          p['p'] as String: 'ontime',
          'updatedAt': now.millisecondsSinceEpoch,
        });
    }
  } catch (e) {
    debugPrint('notification action failed: $e');
  } finally {
    if (own) container.dispose();
  }
}

/// نفس الإشعار تاني بعد شوية
Future<void> _snooze(NotificationResponse r, Duration after) async {
  final n = AppNotifications.instance;
  await n.init();
  if (!n.ready) return;
  final active = await n.android?.getActiveNotifications() ?? const [];
  final old = active.where((a) => a.id == r.id).firstOrNull;
  await n.plugin.zonedSchedule(
    id: r.id ?? 0,
    scheduledDate: tz.TZDateTime.now(tz.local).add(after),
    notificationDetails: AppNotifications.channel(
      'tasks_v2',
      'تذكير المهام',
      'تذكير بمواعيد مهامك',
      actions: NotificationActions.taskButtons,
    ),
    androidScheduleMode: await n.scheduleMode(),
    title: old?.title ?? '⏰ تذكير',
    body: old?.body ?? 'تذكير المهمة (اتأجّل 10 دقايق)',
    payload: r.payload,
  );
}
