import '../../core/utils/date_utils.dart';

/// عادة يومية: users/{uid}/habits/{id}
/// done: خريطة {yyyy-MM-dd: true} بالأيام اللي اتعملت فيها
class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.emoji = '⭐',
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.reminder,
    this.done = const {},
    this.source = 'app',
    required this.createdAt,
  });

  final String id;
  final String title;
  final String emoji;

  /// أيام الأسبوع (DateTime.monday = 1 ... DateTime.sunday = 7)
  final Set<int> weekdays;

  /// "HH:mm" أو null
  final String? reminder;
  final Set<String> done;
  final String source;
  final DateTime createdAt;

  bool isScheduled(DateTime d) => weekdays.contains(d.weekday);
  bool isDoneOn(DateTime d) => done.contains(HayatiDates.dayKey(d));

  /// عدد الأيام المجدولة المتتالية اللي اتعملت فيها العادة.
  /// لو النهارده لسه ما اتعملتش، السلسلة بتتحسب لحد امبارح.
  int streak(DateTime today) {
    var day = DateTime(today.year, today.month, today.day);
    if (!isDoneOn(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    final start = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    ).subtract(const Duration(days: 400));
    while (day.isAfter(start)) {
      if (isScheduled(day)) {
        if (!isDoneOn(day)) break;
        count++;
      }
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// نسبة الالتزام في آخر [days] يوم (للأيام المجدولة بس)
  double completion(DateTime today, {int days = 30}) {
    var scheduled = 0, hits = 0;
    for (var i = 0; i < days; i++) {
      final d = today.subtract(Duration(days: i));
      if (!isScheduled(d)) continue;
      scheduled++;
      if (isDoneOn(d)) hits++;
    }
    return scheduled == 0 ? 0 : hits / scheduled;
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'emoji': emoji,
    'weekdays': weekdays.toList()..sort(),
    'reminder': reminder,
    'done': {for (final d in done) d: true},
    'source': source,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Habit.fromMap(String id, Map<String, dynamic> m) {
    final done = (m['done'] as Map?)?.cast<String, dynamic>() ?? const {};
    final created = m['createdAt'];
    final weekdays = (m['weekdays'] as List?)
        ?.map((e) => (e as num).toInt())
        .toSet();
    return Habit(
      id: id,
      title: (m['title'] ?? '') as String,
      emoji: (m['emoji'] ?? '⭐') as String,
      weekdays: weekdays == null || weekdays.isEmpty
          ? const {1, 2, 3, 4, 5, 6, 7}
          : weekdays,
      reminder: m['reminder'] as String?,
      done: {
        for (final e in done.entries)
          if (e.value == true) e.key,
      },
      source: (m['source'] ?? 'app') as String,
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : DateTime.now(),
    );
  }
}

const weekdayNamesAr = {
  6: 'سبت',
  7: 'أحد',
  1: 'اتنين',
  2: 'تلات',
  3: 'أربع',
  4: 'خميس',
  5: 'جمعة',
};
