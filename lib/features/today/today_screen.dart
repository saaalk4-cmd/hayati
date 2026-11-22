import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/section_card.dart';
import '../../data/session.dart';
import '../../data/tasks_repository.dart';
import '../tasks/add_task_sheet.dart';
import '../family/family_models.dart';
import '../habits/habits_repository.dart';
import '../money/add_transaction_sheet.dart';
import '../money/money_models.dart';
import '../money/money_repository.dart';
import '../money/money_screen.dart';
import '../habits/habits_screen.dart';
import '../tasks/task_tile.dart';
import '../worship/prayer_log.dart';
import '../worship/prayer_service.dart';
import '../worship/worship_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final name = session is UserSession
        ? (session.name?.split(' ').first ?? '')
        : '';
    final today = HayatiDates.dayKey(_now);
    final tasks = ref.watch(tasksProvider).value ?? const [];
    final todays = tasks
        .where((t) => t.dueDate == today || (t.dueDate == null && !t.done))
        .toList();
    final remaining = todays.where((t) => !t.done).length;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/assistant'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('اسأل حياتي'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _Header(now: _now, name: name),
            const SizedBox(height: 12),
            const _PlanMyDayButton(),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.go('/worship'),
              child: const NextPrayerHero(compact: true),
            ),
            const SizedBox(height: 12),
            const _PrayersRow(),
            const SizedBox(height: 12),
            SectionCard(
              icon: Icons.check_circle,
              title: 'مهام النهارده',
              trailing: Text(
                todays.isEmpty ? '' : 'باقي $remaining',
                style: text.labelLarge?.copyWith(color: AppColors.gold700),
              ),
              onTap: () => context.go('/tasks'),
              child: todays.isEmpty
                  ? Row(
                      children: [
                        const Expanded(
                          child: Text('يومك فاضي، تحب تضيف مهمة؟'),
                        ),
                        TextButton(
                          onPressed: () => showAddTaskSheet(context),
                          child: const Text('إضافة'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        for (final t in todays.take(5))
                          TaskTile(task: t, dense: true),
                        if (todays.length > 5)
                          Text(
                            'و ${todays.length - 5} كمان...',
                            style: text.bodySmall,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            const _HabitsCard(),
            const SizedBox(height: 12),
            const _MoneyCard(),
            const _UpcomingCard(),
            const SizedBox(height: 12),
            const _VerseCard(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.name});
  final DateTime now;
  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emerald700, AppColors.emerald900],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty
                ? HayatiDates.greeting(now)
                : '${HayatiDates.greeting(now)} يا $name',
            style: text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            HayatiDates.gregorian(now),
            style: text.bodyLarge?.copyWith(color: Colors.white70),
          ),
          Text(
            HayatiDates.hijri(now),
            style: text.bodyLarge?.copyWith(color: AppColors.gold500),
          ),
        ],
      ),
    );
  }
}

/// آيات قصيرة ثابتة مع مرجعها (السورة: الآية)
class _VerseCard extends StatelessWidget {
  const _VerseCard();

  static const _verses = [
    ('فَإِنَّ مَعَ الْعُسْرِ يُسْرًا', 'الشرح: 5'),
    ('وَقُل رَّبِّ زِدْنِي عِلْمًا', 'طه: 114'),
    ('أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ', 'الرعد: 28'),
    ('وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ', 'الطلاق: 3'),
    ('إِنَّ اللَّهَ مَعَ الصَّابِرِينَ', 'البقرة: 153'),
    ('فَاذْكُرُونِي أَذْكُرْكُمْ', 'البقرة: 152'),
    ('وَاصْبِرْ وَمَا صَبْرُكَ إِلَّا بِاللَّهِ', 'النحل: 127'),
  ];

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    final (verse, ref) = _verses[day % _verses.length];
    return SectionCard(
      icon: Icons.menu_book,
      title: 'آية اليوم',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            verse,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(height: 1.8, fontWeight: FontWeight.w600),
          ),
          Text(
            '﴿$ref﴾',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// خمس دوائر صغيرة بحالة صلوات النهارده
class _PrayersRow extends ConsumerWidget {
  const _PrayersRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(todayPrayerLogProvider);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/worship'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final p in PrayerName.values)
                Column(
                  children: [
                    Icon(
                      log[p] == null
                          ? Icons.radio_button_unchecked
                          : log[p] == PrayerStatus.missed
                          ? Icons.cancel
                          : Icons.check_circle,
                      color: log[p] == null
                          ? scheme.outline
                          : log[p] == PrayerStatus.missed
                          ? scheme.error
                          : scheme.primary,
                    ),
                    const SizedBox(height: 4),
                    Text(p.ar, style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// عادات النهارده (المجدولة لليوم بس)
class _HabitsCard extends ConsumerWidget {
  const _HabitsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final habits = (ref.watch(habitsProvider).value ?? const [])
        .where((h) => h.isScheduled(now))
        .toList();
    final done = habits.where((h) => h.isDoneOn(now)).length;
    return SectionCard(
      icon: Icons.local_fire_department,
      title: 'عادات النهارده',
      trailing: habits.isEmpty
          ? null
          : Text(
              '$done/${habits.length}',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AppColors.gold700),
            ),
      onTap: () => context.push('/more/habits'),
      child: habits.isEmpty
          ? const Text('ضيف عادة صغيرة تبدأ بيها يومك 🌱')
          : Column(
              children: [
                for (final h in habits.take(4))
                  HabitCard(habit: h, compact: true),
              ],
            ),
    );
  }
}

/// مصروف النهارده + إضافة سريعة
class _MoneyCard extends ConsumerWidget {
  const _MoneyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = HayatiDates.dayKey(now);
    final txs =
        ref.watch(monthTransactionsProvider(monthKey(now))).value ?? const [];
    final spentToday = txs
        .where((t) => t.date == today && t.type == TxType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    final spentMonth = MonthSummary(txs).spent;
    return SectionCard(
      icon: Icons.account_balance_wallet,
      title: 'مصروف النهارده',
      onTap: () => context.go('/money'),
      trailing: IconButton(
        tooltip: 'سجّل مصروف',
        onPressed: () => showAddTransactionSheet(context),
        icon: const Icon(Icons.add_circle, color: AppColors.gold500),
      ),
      child: Row(
        children: [
          Text(
            formatMoney(spentToday),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            'الشهر: ${formatMoney(spentMonth)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// مناسبات قريبة (خلال أسبوع) وناس وحشوك — بيظهر بس لو فيه حاجة
class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final occasions = (ref.watch(occasionsProvider).value ?? const [])
        .where((o) => o.daysUntil(now) <= 7)
        .toList();
    final due = (ref.watch(peopleProvider).value ?? const [])
        .where((p) => p.isDue(now) && p.lastContact != null)
        .take(3)
        .toList();
    if (occasions.isEmpty && due.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        icon: Icons.cake,
        title: 'قريب',
        onTap: () => context.push('/more/occasions'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final o in occasions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${o.type.emoji} ${o.title} • ${o.daysUntil(now) == 0
                      ? 'النهارده'
                      : o.daysUntil(now) == 1
                      ? 'بكرة'
                      : 'بعد ${o.daysUntil(now)} أيام'}',
                ),
              ),
            for (final p in due)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '💚 بقالك ${p.daysSince(now)} يوم ما كلمتش ${p.name}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// زرار «رتّبلي يومي» بيفتح المساعد ويبعتله الطلب على طول
class _PlanMyDayButton extends StatelessWidget {
  const _PlanMyDayButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold500.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(
          '/assistant?q=${Uri.encodeQueryComponent('رتّبلي يومي النهارده')}',
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.gold700),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'رتّبلي يومي',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('خطة ذكية من Claude', style: TextStyle(fontSize: 12)),
              Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}
