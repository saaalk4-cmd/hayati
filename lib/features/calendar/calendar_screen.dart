import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/palettes.dart';
import '../../core/utils/date_utils.dart';
import '../../data/task.dart';
import '../../data/tasks_repository.dart';
import '../family/family_models.dart';
import '../journal/journal_repository.dart';
import '../tasks/task_tile.dart';
import '../worship/islamic_occasions.dart';
import '../worship/prayer_log.dart';

/// أسماء أيام الأسبوع بالترتيب المصري (السبت أول الأسبوع)
const _weekHeader = ['سبت', 'أحد', 'اتنين', 'تلات', 'أربع', 'خميس', 'جمعة'];

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final tasks = ref.watch(tasksProvider).value ?? const <HayatiTask>[];
    final occasions = ref.watch(occasionsProvider).value ?? const <Occasion>[];
    final journal = ref.watch(journalProvider).value ?? const <JournalEntry>[];
    final moods = {for (final e in journal) e.day: e.mood};
    final islamic = {
      for (final o in upcomingIslamicOccasions(
        _month.subtract(const Duration(days: 1)),
      ))
        HayatiDates.dayKey(o.date): o.occasion,
    };

    // السبت = 0 ... الجمعة = 6
    final first = _month;
    final lead = (first.weekday + 1) % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = lead + daysInMonth;
    final today = HayatiDates.dayKey(DateTime.now());

    List<HayatiTask> tasksOn(String key) =>
        tasks.where((t) => t.dueDate == key).toList();
    List<Occasion> occasionsOn(DateTime d) =>
        occasions.where((o) => o.month == d.month && o.day == d.day).toList();

    final selKey = HayatiDates.dayKey(_selected);
    final selTasks = tasksOn(selKey);
    final selOcc = occasionsOn(_selected);
    final selIslamic = islamic[selKey];
    final selPrayers = ref.watch(prayerLogProvider(selKey)).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('تقويمي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      arFormat('MMMM y', _month),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _hijriRange(_month),
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: p.accent),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final w in _weekHeader)
                        Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: text.labelSmall?.copyWith(color: p.muted),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ((cells + 6) ~/ 7) * 7,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.8,
                        ),
                    itemBuilder: (_, i) {
                      final dayNum = i - lead + 1;
                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return const SizedBox();
                      }
                      final d = DateTime(_month.year, _month.month, dayNum);
                      final key = HayatiDates.dayKey(d);
                      final hasTask = tasks.any(
                        (t) => t.dueDate == key && !t.done,
                      );
                      final hasOcc =
                          occasionsOn(d).isNotEmpty || islamic.containsKey(key);
                      final mood = moods[key];
                      final selected = key == selKey;
                      final isToday = key == today;
                      final hijriDay = HijriCalendar.fromDate(
                        d.add(Duration(days: HayatiDates.hijriAdjust)),
                      ).hDay;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: selected
                                ? p.accent.withValues(alpha: 0.22)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday
                                ? Border.all(color: p.accent, width: 1.5)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isToday ? p.accent : p.text,
                                ),
                              ),
                              Text(
                                '$hijriDay',
                                style: TextStyle(fontSize: 9, color: p.muted),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (hasTask) _dot(p.accent),
                                  if (hasOcc) _dot(p.primary),
                                  if (mood != null)
                                    _dot(p.text.withValues(alpha: 0.6)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dot(p.accent),
                const Text(' مهام   '),
                _dot(p.primary),
                const Text(' مناسبات   '),
                _dot(p.text.withValues(alpha: 0.6)),
                const Text(' يومية'),
              ],
            ),
          ),
          Text(
            '${arFormat('EEEE d MMMM', _selected)} • ${HayatiDates.hijri(_selected)}',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (selIslamic != null)
            Card(
              child: ListTile(
                leading: Text(
                  selIslamic.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
                title: Text(selIslamic.name),
                subtitle: selIslamic.fasting ? const Text('صيام مستحب') : null,
              ),
            ),
          for (final o in selOcc)
            Card(
              child: ListTile(
                leading: Text(
                  o.type.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
                title: Text(o.title),
              ),
            ),
          if (selPrayers.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.mosque),
                title: Text(
                  'صليت ${selPrayers.values.where((s) => s != PrayerStatus.missed).length} من 5',
                ),
              ),
            ),
          if (moods[selKey] != null)
            Card(
              child: ListTile(
                leading: Text(
                  moodEmojis[moods[selKey]]!,
                  style: const TextStyle(fontSize: 26),
                ),
                title: Text('مزاجك: ${moodNames[moods[selKey]]}'),
              ),
            ),
          if (selTasks.isEmpty && selOcc.isEmpty && selIslamic == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('مفيش حاجة في اليوم ده', textAlign: TextAlign.center),
            )
          else
            Card(
              child: Column(
                children: [for (final t in selTasks) TaskTile(task: t)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  String _hijriRange(DateTime m) {
    final a = HijriCalendar.fromDate(
      m.add(Duration(days: HayatiDates.hijriAdjust)),
    );
    final end = DateTime(m.year, m.month + 1, 0);
    final b = HijriCalendar.fromDate(
      end.add(Duration(days: HayatiDates.hijriAdjust)),
    );
    HijriCalendar.setLocal('ar');
    return a.hMonth == b.hMonth
        ? '${a.longMonthName} ${a.hYear} هـ'
        : '${a.longMonthName} – ${b.longMonthName} ${b.hYear} هـ';
  }
}
