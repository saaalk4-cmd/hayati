import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/utils/date_utils.dart';
import '../../data/tasks_repository.dart';
import '../habits/habits_repository.dart';
import '../worship/prayer_service.dart';
import '../worship/prayer_settings.dart';

/// البيانات اللي بتتبعت للويدجت
class WidgetPayload {
  const WidgetPayload(this.names, this.times, this.tasksLine, this.habitsLine);
  final String names;
  final String times;
  final String tasksLine;
  final String habitsLine;

  @override
  bool operator ==(Object other) =>
      other is WidgetPayload &&
      other.names == names &&
      other.times == times &&
      other.tasksLine == tasksLine &&
      other.habitsLine == habitsLine;

  @override
  int get hashCode => Object.hash(names, times, tasksLine, habitsLine);
}

/// مواعيد صلوات النهارده + فجر بكرة، والويدجت بيختار الجاية بنفسه
WidgetPayload buildWidgetPayload({
  required PrayerSettings settings,
  required DateTime now,
  required int tasksLeft,
  required int habitsDone,
  required int habitsTotal,
}) {
  final today = computePrayerTimes(settings, now);
  final tomorrow = computePrayerTimes(
    settings,
    now.add(const Duration(days: 1)),
  );
  final names = [for (final p in PrayerName.values) p.ar, PrayerName.fajr.ar];
  final times = [
    for (final p in PrayerName.values) today[p].millisecondsSinceEpoch,
    tomorrow[PrayerName.fajr].millisecondsSinceEpoch,
  ];
  return WidgetPayload(
    names.join(','),
    times.join(','),
    tasksLeft == 0
        ? 'مهام النهارده: خلصت كلها 👌'
        : 'مهام النهارده: باقي $tasksLeft',
    habitsTotal == 0 ? '' : 'عادات النهارده: $habitsDone/$habitsTotal',
  );
}

final widgetPayloadProvider = Provider<WidgetPayload>((ref) {
  final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
  final key = HayatiDates.dayKey(now);
  final tasks = ref.watch(tasksProvider).value ?? const [];
  final habits = (ref.watch(habitsProvider).value ?? const [])
      .where((h) => h.isScheduled(now))
      .toList();
  return buildWidgetPayload(
    settings: ref.watch(prayerSettingsProvider),
    now: now,
    tasksLeft: tasks
        .where(
          (t) => !t.done && t.dueDate != null && t.dueDate!.compareTo(key) <= 0,
        )
        .length,
    habitsDone: habits.where((h) => h.isDoneOn(now)).length,
    habitsTotal: habits.length,
  );
});

class HomeWidgetSync {
  static WidgetPayload? _last;

  static Future<void> push(WidgetPayload p) async {
    if (p == _last) return;
    _last = p;
    try {
      await HomeWidget.saveWidgetData<String>('prayer_names', p.names);
      await HomeWidget.saveWidgetData<String>('prayer_times', p.times);
      await HomeWidget.saveWidgetData<String>('tasks_line', p.tasksLine);
      await HomeWidget.saveWidgetData<String>('habits_line', p.habitsLine);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.hayati.hayati.HayatiWidgetProvider',
      );
    } catch (e) {
      debugPrint('home widget update failed: $e');
    }
  }
}
