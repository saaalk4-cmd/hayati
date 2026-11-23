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
import '../account/guest_migration.dart';
import '../family/family_models.dart';
import '../habits/habits_repository.dart';
import '../onboarding/onboarding_screen.dart';
import '../ramadan/ramadan.dart';
import '../ramadan/ramadan_screen.dart';
import '../money/add_transaction_sheet.dart';
import '../money/money_models.dart';
import '../money/money_repository.dart';
import '../money/money_screen.dart';
import '../habits/habits_screen.dart';
import '../tasks/task_tile.dart';
import '../worship/prayer_log.dart';
import '../worship/prayer_service.dart';
import '../worship/worship_screen.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/motion.dart';

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
    final local = ref.watch(localNameProvider);
    final name = session is UserSession && (session.name?.isNotEmpty ?? false)
        ? session.name!.split(' ').first
        : (local ?? '');
    final today = HayatiDates.dayKey(_now);
    final tasks = ref.watch(tasksProvider).value ?? const [];
    final todays = tasks
        .where((t) => t.dueDate == today || (t.dueDate == null && !t.done))
        .toList();
    final remaining = todays.where((t) => !t.done).length;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        shape: const StadiumBorder(),
        onPressed: () => context.push('/assistant'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text(
          'اسأل حياتي',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: staggered([
            _Header(now: _now, name: name),
            const SizedBox(height: 12),
            const _GuestMigrationBanner(),
            const _PlanMyDayButton(),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.go('/worship'),
              child: const NextPrayerHero(compact: true),
            ),
            const SizedBox(height: 12),
            const _PrayersRow(),
            const _RamadanSlot(),
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
          ]),
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
        gradient: context.palette.hero,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
    final next = ref.watch(nextPrayerProvider);
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final nextIsToday = next.time.day == now.day;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go('/worship'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final p in PrayerName.values)
              PrayerDot(
                prayer: p,
                status: log[p],
                isNext: nextIsToday && next.name == p,
              ),
          ],
        ),
      ),
    );
  }
}

/// دايرة صلاة بأيقونتها: متعلّم عليها ✓، أو الجاية (ذهبي)، أو لسه
class PrayerDot extends StatelessWidget {
  const PrayerDot({
    super.key,
    required this.prayer,
    required this.status,
    required this.isNext,
  });

  final PrayerName prayer;
  final PrayerStatus? status;
  final bool isNext;

  static const _icons = {
    PrayerName.fajr: Icons.wb_twilight,
    PrayerName.dhuhr: Icons.wb_sunny_outlined,
    PrayerName.asr: Icons.light_mode_outlined,
    PrayerName.maghrib: Icons.wb_twilight_outlined,
    PrayerName.isha: Icons.nights_stay_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = status != null && status != PrayerStatus.missed;
    final missed = status == PrayerStatus.missed;
    final ring = isNext
        ? AppColors.gold500
        : done
        ? AppColors.emerald500
        : missed
        ? scheme.error
        : scheme.outlineVariant;
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardTheme.color,
            border: Border.all(color: ring, width: isNext ? 3 : 2),
            boxShadow: isNext
                ? [
                    BoxShadow(
                      color: AppColors.gold500.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            done
                ? Icons.check
                : missed
                ? Icons.close
                : isNext
                ? Icons.schedule
                : _icons[prayer],
            color: done
                ? AppColors.emerald500
                : missed
                ? scheme.error
                : isNext
                ? AppColors.gold700
                : scheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          prayer.ar,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        if (isNext)
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.gold500,
              shape: BoxShape.circle,
            ),
          ),
      ],
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

/// لو سجّل دخول وعنده بيانات من وضع الضيف، نعرض عليه ينقلها
class _GuestMigrationBanner extends ConsumerStatefulWidget {
  const _GuestMigrationBanner();

  @override
  ConsumerState<_GuestMigrationBanner> createState() =>
      _GuestMigrationBannerState();
}

class _GuestMigrationBannerState extends ConsumerState<_GuestMigrationBanner> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(guestMigrationProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: context.palette.accent.withValues(alpha: 0.16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'عندك بيانات من وضع الضيف على الموبايل ده',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text('ننقلها لحسابك عشان تتحفظ ومتضيعش؟'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                final n = await ref
                                    .read(guestMigrationProvider.notifier)
                                    .migrate();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('نقلنا $n عنصر لحسابك ✓'),
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تعذّر النقل، اتأكد من النت وجرّب تاني',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      child: const Text('انقلها'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => ref
                              .read(guestMigrationProvider.notifier)
                              .dismiss(),
                    child: const Text('لا، امسحها'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة رمضان في الشاشة الرئيسية: في رمضان، أو لما يفضل عليه 10 أيام أو أقل
class _RamadanSlot extends ConsumerWidget {
  const _RamadanSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ramadanInfo(
      DateTime.now(),
      adjustDays: ref.watch(ramadanAdjustProvider),
    );
    if (!info.isRamadan && info.daysUntilRamadan > 10) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () => context.push('/worship/ramadan'),
        child: const RamadanHero(),
      ),
    );
  }
}
