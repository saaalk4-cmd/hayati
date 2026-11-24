import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/notification_actions.dart';
import 'package:hayati/core/utils/date_utils.dart';
import 'package:hayati/data/session.dart';
import 'package:hayati/data/tasks_repository.dart';
import 'package:hayati/data/user_store.dart';
import 'package:hayati/features/habits/habit.dart';
import 'package:hayati/features/habits/habits_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('أزرار الإشعار بتسجّل: خلصت المهمة، عملت العادة، صليت', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        firebaseReadyProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    NotificationActions.appContainer = c;
    addTearDown(() => NotificationActions.appContainer = null);

    final tasks = c.read(tasksRepositoryProvider);
    await tasks.add('أكلم ماما');
    final task = (await tasks.watch().first).single;
    final habits = c.read(habitsRepositoryProvider);
    await habits.save(
      Habit(id: 'h1', title: 'رياضة', createdAt: DateTime(2026)),
    );
    final habit = (await habits.watch().first).single;

    NotificationResponse tap(String action, String payload) =>
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 1,
          actionId: action,
          payload: payload,
        );

    await handleNotificationAction(
      tap(NotificationActions.done, NotificationActions.taskPayload(task.id)),
    );
    expect((await tasks.watch().first).single.done, isTrue);

    await handleNotificationAction(
      tap(NotificationActions.done, NotificationActions.habitPayload(habit.id)),
    );
    expect(
      (await habits.watch().first).single.isDoneOn(DateTime.now()),
      isTrue,
    );

    final now = DateTime.now();
    await handleNotificationAction(
      tap(
        NotificationActions.prayed,
        NotificationActions.prayerPayload('dhuhr', now),
      ),
    );
    final log = await c
        .read(userStoreProvider)
        .get('prayers', HayatiDates.dayKey(now));
    expect(log?['dhuhr'], 'ontime');

    // دوسة عادية على الإشعار (من غير زرار) مبتغيّرش حاجة
    await handleNotificationAction(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '{"t":"task","id":"x"}',
      ),
    );
  });
}
