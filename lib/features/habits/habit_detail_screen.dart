import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import 'habit.dart';
import 'habit_editor.dart';
import 'habits_repository.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(habitsProvider).value;
    final habit = list?.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: list == null
              ? const CircularProgressIndicator()
              : const Text('العادة دي اتمسحت'),
        ),
      );
    }
    final today = DateTime.now();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${habit.emoji} ${habit.title}'),
        actions: [
          IconButton(
            onPressed: () => showHabitEditor(context, habit: habit),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _Stat(
                label: 'السلسلة الحالية',
                value: '🔥 ${habit.streak(today)}',
              ),
              const SizedBox(width: 12),
              _Stat(
                label: 'التزام آخر 30 يوم',
                value: '${(habit.completion(today) * 100).round()}%',
              ),
              const SizedBox(width: 12),
              _Stat(label: 'إجمالي الأيام', value: '${habit.done.length}'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'آخر 12 أسبوع',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'دوس على أي يوم عشان تعلّم عليه أو تشيل العلامة',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _Heatmap(habit: habit),
                ],
              ),
            ),
          ),
          if (habit.reminder != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.alarm),
                title: Text('تذكير الساعة ${habit.reminder}'),
                subtitle: Text(
                  habit.weekdays.length == 7
                      ? 'كل يوم'
                      : weekdayNamesAr.entries
                            .where((e) => habit.weekdays.contains(e.key))
                            .map((e) => e.value)
                            .join('، '),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// خريطة حرارية: 12 عمود (أسابيع) × 7 صفوف (من السبت للجمعة)
class _Heatmap extends ConsumerWidget {
  const _Heatmap({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // أول السبت من 11 أسبوع فاتوا
    final offset = (today.weekday + 1) % 7; // السبت = 0
    final start = today.subtract(Duration(days: offset + 7 * 11));
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        final cell = (c.maxWidth - 11 * 4) / 12;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var w = 0; w < 12; w++)
              Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    Builder(
                      builder: (context) {
                        final day = start.add(Duration(days: w * 7 + d));
                        final future = day.isAfter(today);
                        final done = habit.isDoneOn(day);
                        final sched = habit.isScheduled(day);
                        return GestureDetector(
                          onTap: future
                              ? null
                              : () => ref
                                    .read(habitsRepositoryProvider)
                                    .setDone(habit, day, !done),
                          child: Container(
                            width: cell,
                            height: cell,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: future
                                  ? Colors.transparent
                                  : done
                                  ? AppColors.emerald500
                                  : sched
                                  ? scheme.outlineVariant.withValues(
                                      alpha: 0.35,
                                    )
                                  : scheme.outlineVariant.withValues(
                                      alpha: 0.12,
                                    ),
                              border: day == today
                                  ? Border.all(
                                      color: AppColors.gold500,
                                      width: 2,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
