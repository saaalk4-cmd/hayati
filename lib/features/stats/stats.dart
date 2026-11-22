import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../data/task.dart';
import '../../data/tasks_repository.dart';
import '../habits/habit.dart';
import '../habits/habits_repository.dart';
import '../journal/journal_repository.dart';
import '../money/money_models.dart';
import '../money/money_repository.dart';
import '../money/money_screen.dart';
import '../worship/prayer_log.dart';
import '../worship/prayer_service.dart';
import '../worship/quran_progress.dart';

enum StatsPeriod { week, month }

class StatsResult {
  const StatsResult({
    required this.days,
    required this.prayersDone,
    required this.prayersMosque,
    required this.prayersPerDay,
    required this.habitRate,
    required this.tasksDone,
    required this.tasksTotal,
    required this.spent,
    required this.income,
    required this.quranPages,
    required this.avgMood,
  });

  final List<DateTime> days;
  final int prayersDone;
  final int prayersMosque;

  /// عدد الصلوات المسجّلة (مش فايتة) في كل يوم
  final List<int> prayersPerDay;
  final double habitRate;
  final int tasksDone;
  final int tasksTotal;
  final double spent;
  final double income;
  final int quranPages;
  final double? avgMood;

  int get prayersTotal => days.length * 5;
  double get prayerRate => prayersTotal == 0 ? 0 : prayersDone / prayersTotal;

  String shareText(StatsPeriod p) {
    final label = p == StatsPeriod.week ? 'أسبوعي' : 'شهري';
    return [
      '📊 ملخصي ال$label من «حياتي»',
      '🕌 الصلوات: $prayersDone من $prayersTotal (في المسجد $prayersMosque)',
      '🔥 الالتزام بالعادات: ${(habitRate * 100).round()}%',
      '✅ المهام: خلصت $tasksDone من $tasksTotal',
      '📖 القرآن: $quranPages صفحة',
      '💰 المصروف: ${formatMoney(spent)}',
      if (avgMood != null)
        '🙂 متوسط المزاج: ${avgMood!.toStringAsFixed(1)} من 5',
    ].join('\n');
  }
}

List<DateTime> periodDays(StatsPeriod p, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final n = p == StatsPeriod.week ? 7 : 30;
  return [for (var i = n - 1; i >= 0; i--) today.subtract(Duration(days: i))];
}

/// الحساب نفسه (من غير Riverpod) عشان يتختبر بسهولة
StatsResult computeStats({
  required List<DateTime> days,
  required Map<String, Map<PrayerName, PrayerStatus>> prayerLogs,
  required List<Habit> habits,
  required List<HayatiTask> tasks,
  required List<Transaction> transactions,
  required Map<String, int> quranLog,
  required List<JournalEntry> journal,
}) {
  final keys = days.map(HayatiDates.dayKey).toSet();
  var done = 0, mosque = 0;
  final perDay = <int>[];
  for (final d in days) {
    final log = prayerLogs[HayatiDates.dayKey(d)] ?? const {};
    final c = log.values.where((s) => s != PrayerStatus.missed).length;
    done += c;
    mosque += log.values.where((s) => s == PrayerStatus.mosque).length;
    perDay.add(c);
  }

  var scheduled = 0, hits = 0;
  for (final h in habits) {
    for (final d in days) {
      final created =
          DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      if (!h.isScheduled(d) || d.isBefore(created)) continue;
      scheduled++;
      if (h.isDoneOn(d)) hits++;
    }
  }

  final periodTasks = tasks.where(
    (t) => t.dueDate != null && keys.contains(t.dueDate),
  );
  final txs = transactions.where((t) => keys.contains(t.date));
  final moods = journal
      .where((e) => keys.contains(e.day) && e.mood != null)
      .map((e) => e.mood!)
      .toList();

  return StatsResult(
    days: days,
    prayersDone: done,
    prayersMosque: mosque,
    prayersPerDay: perDay,
    habitRate: scheduled == 0 ? 0 : hits / scheduled,
    tasksDone: periodTasks.where((t) => t.done).length,
    tasksTotal: periodTasks.length,
    spent: txs
        .where((t) => t.type == TxType.expense)
        .fold(0, (s, t) => s + t.amount),
    income: txs
        .where((t) => t.type == TxType.income)
        .fold(0, (s, t) => s + t.amount),
    quranPages: keys.fold(0, (s, k) => s + (quranLog[k] ?? 0)),
    avgMood: moods.isEmpty
        ? null
        : moods.reduce((a, b) => a + b) / moods.length,
  );
}

final statsProvider = Provider.family<StatsResult, StatsPeriod>((ref, period) {
  final days = periodDays(period, DateTime.now());
  final months = days.map(monthKey).toSet();
  return computeStats(
    days: days,
    prayerLogs: {
      for (final d in days)
        HayatiDates.dayKey(d):
            ref.watch(prayerLogProvider(HayatiDates.dayKey(d))).value ??
            const {},
    },
    habits: ref.watch(habitsProvider).value ?? const [],
    tasks: ref.watch(tasksProvider).value ?? const [],
    transactions: [
      for (final m in months) ...?ref.watch(monthTransactionsProvider(m)).value,
    ],
    quranLog: ref.watch(quranProgressProvider).value?.log ?? const {},
    journal: ref.watch(journalProvider).value ?? const [],
  );
});
