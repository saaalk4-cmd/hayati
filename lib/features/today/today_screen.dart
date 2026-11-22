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
import '../tasks/task_tile.dart';

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
        const Duration(minutes: 1), (_) => setState(() => _now = DateTime.now()));
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
            const SizedBox(height: 16),
            SectionCard(
              icon: Icons.mosque,
              title: 'الصلاة الجاية',
              onTap: () => context.go('/worship'),
              child: Text(
                'مواقيت الصلاة والأذان في المرحلة الجاية إن شاء الله.',
                style: text.bodyMedium,
              ),
            ),
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
                        const Expanded(child: Text('يومك فاضي، تحب تضيف مهمة؟')),
                        TextButton(
                          onPressed: () => showAddTaskSheet(context),
                          child: const Text('إضافة'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        for (final t in todays.take(5)) TaskTile(task: t, dense: true),
                        if (todays.length > 5)
                          Text('و ${todays.length - 5} كمان...',
                              style: text.bodySmall),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SectionCard(
                    icon: Icons.local_fire_department,
                    title: 'عاداتي',
                    onTap: () => context.go('/more'),
                    child: const Text('قريبًا'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SectionCard(
                    icon: Icons.account_balance_wallet,
                    title: 'مصروف اليوم',
                    onTap: () => context.go('/money'),
                    child: const Text('قريبًا'),
                  ),
                ),
              ],
            ),
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
            style: text.headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(HayatiDates.gregorian(now),
              style: text.bodyLarge?.copyWith(color: Colors.white70)),
          Text(HayatiDates.hijri(now),
              style: text.bodyLarge?.copyWith(color: AppColors.gold500)),
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
          Text(verse,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(height: 1.8, fontWeight: FontWeight.w600)),
          Text('﴿$ref﴾',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
