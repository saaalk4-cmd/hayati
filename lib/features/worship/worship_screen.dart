import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/section_card.dart';
import 'prayer_log.dart';
import 'prayer_service.dart';
import 'prayer_settings.dart';
import 'quran_progress.dart';

class WorshipScreen extends ConsumerWidget {
  const WorshipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerSettingsProvider);
    final quran = ref.watch(quranProgressProvider).value;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('عباداتي'),
        actions: [
          IconButton(
            tooltip: 'إعدادات المواقيت',
            onPressed: () => context.push('/worship/settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const NextPrayerHero(),
          if (!settings.hasRealLocation) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.gold200.withValues(alpha: 0.6),
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('المواقيت محسوبة على القاهرة'),
                subtitle: const Text('حدد موقعك عشان تبقى دقيقة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/worship/settings'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('صلوات النهارده',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const PrayerChecklist(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  icon: Icons.wb_twilight,
                  title: 'أذكار الصباح',
                  onTap: () => context.push('/worship/adhkar/morning'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Tile(
                  icon: Icons.nights_stay_outlined,
                  title: 'أذكار المساء',
                  onTap: () => context.push('/worship/adhkar/evening'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  icon: Icons.self_improvement,
                  title: 'بعد الصلاة',
                  onTap: () => context.push('/worship/adhkar/after_prayer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Tile(
                  icon: Icons.explore_outlined,
                  title: 'اتجاه القبلة',
                  onTap: () => context.push('/worship/qibla'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.menu_book,
            title: 'وِردي من القرآن',
            onTap: () => context.push('/worship/quran'),
            trailing: quran == null
                ? null
                : Text('${quran.todayPages}/${quran.dailyGoal} صفحة',
                    style: text.labelLarge?.copyWith(color: AppColors.gold700)),
            child: quran == null
                ? const LinearProgressIndicator()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: quran.khatmaFraction,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      Text(quran.page == 0
                          ? 'ابدأ ختمة جديدة'
                          : 'وصلت صفحة ${quran.page} • الجزء ${juzOfPage(quran.page)}'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary, size: 30),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة الصلاة الجاية بعدّاد تنازلي (بتظهر في «يومي» و«عباداتي»)
class NextPrayerHero extends ConsumerWidget {
  const NextPrayerHero({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextPrayerProvider);
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emerald700, AppColors.emerald900],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.mosque, color: AppColors.gold500, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الصلاة الجاية',
                    style: text.bodyMedium?.copyWith(color: Colors.white70)),
                Text(
                  '${next.name.ar} • ${formatPrayerTime(next.time)}',
                  style: text.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
                Text(formatCountdown(next.time.difference(now)),
                    style: text.bodyLarge?.copyWith(color: AppColors.gold500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// قائمة الصلوات الخمس بمواعيدها وحالة كل صلاة
class PrayerChecklist extends ConsumerWidget {
  const PrayerChecklist({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final times = ref.watch(todayPrayerTimesProvider);
    final log = ref.watch(todayPrayerLogProvider);
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        children: [
          for (final p in PrayerName.values)
            ListTile(
              leading: Icon(
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
              title: Text(p.ar,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: log[p] == null ? null : Text(log[p]!.ar),
              trailing: Text(formatPrayerTime(times[p])),
              enabled: !times[p].isAfter(now) || log[p] != null,
              onTap: () => _pick(context, ref, p),
            ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, PrayerName p) async {
    final day = HayatiDates.dayKey(DateTime.now());
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('صلاة ${p.ar}', style: Theme.of(c).textTheme.titleLarge),
            for (final s in PrayerStatus.values)
              ListTile(
                title: Text(s.ar),
                onTap: () => Navigator.pop(c, s),
              ),
            ListTile(
              title: const Text('مسح'),
              leading: const Icon(Icons.clear),
              onTap: () => Navigator.pop(c, 'clear'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await logPrayer(ref, day, p, choice is PrayerStatus ? choice : null);
  }
}
