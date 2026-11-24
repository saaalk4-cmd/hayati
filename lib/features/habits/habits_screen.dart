import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/graphics.dart';
import '../../core/sound/sfx.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/motion.dart';
import 'habit.dart';
import 'habit_editor.dart';
import 'habits_repository.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('عاداتي')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showHabitEditor(context),
        child: const Icon(Icons.add),
      ),
      body: habits.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const Center(child: Text('تعذّر تحميل العادات')),
        data: (list) => list.isEmpty
            ? const _Empty()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => HabitCard(habit: list[i]),
              ),
      ),
    );
  }
}

class HabitCard extends ConsumerWidget {
  const HabitCard({super.key, required this.habit, this.compact = false});
  final Habit habit;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final doneToday = habit.isDoneOn(today);
    final scheduled = habit.isScheduled(today);
    final streak = habit.streak(today);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final check = InkWell(
      customBorder: const CircleBorder(),
      onTap: () async {
        if (!doneToday) SoundFx.play(Sfx.done);
        await ref
            .read(habitsRepositoryProvider)
            .setDone(habit, today, !doneToday);
        // لو دي كانت آخر عادة النهارده: احتفال 🎉
        if (!doneToday && context.mounted) {
          final all = (ref.read(habitsProvider).value ?? const []).where(
            (h) => h.isScheduled(today),
          );
          final rest = all.where((h) => h.id != habit.id && !h.isDoneOn(today));
          if (rest.isEmpty) {
            HapticFeedback.heavyImpact();
            showCelebration(context);
          }
        }
      },
      child: PopOnChange(
        value: doneToday,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: doneToday ? scheme.primary : Colors.transparent,
            border: Border.all(
              color: doneToday ? scheme.primary : scheme.outline,
              width: 2,
            ),
          ),
          child: doneToday
              ? const Icon(Icons.check, color: Colors.white)
              : null,
        ),
      ),
    );

    if (compact) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Text(habit.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(habit.title),
        subtitle: streak > 0 ? Text('🔥 $streak يوم') : null,
        trailing: check,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/more/habits/${habit.id}'),
        onLongPress: () => showHabitEditor(context, habit: habit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(habit.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          !scheduled
                              ? 'مش مطلوبة النهارده'
                              : streak > 0
                              ? '🔥 $streak يوم ورا بعض'
                              : 'ابدأ السلسلة النهارده',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  check,
                ],
              ),
              const SizedBox(height: 12),
              _Last7(habit: habit),
            ],
          ),
        ),
      ),
    );
  }
}

class _Last7 extends StatelessWidget {
  const _Last7({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 6; i >= 0; i--)
          Builder(
            builder: (context) {
              final d = today.subtract(Duration(days: i));
              final done = habit.isDoneOn(d);
              final sched = habit.isScheduled(d);
              return Column(
                children: [
                  Text(
                    weekdayNamesAr[d.weekday]!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.gold500
                          : sched
                          ? scheme.outlineVariant.withValues(alpha: 0.4)
                          : Colors.transparent,
                      border: i == 0
                          ? Border.all(color: scheme.primary, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${d.day}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              'ابدأ بعادة واحدة صغيرة كل يوم.\nالقليل الدائم أحسن من الكتير المتقطع.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => showHabitEditor(context),
              child: const Text('ضيف أول عادة'),
            ),
          ],
        ),
      ),
    );
  }
}
