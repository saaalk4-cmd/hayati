import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../worship/prayer_service.dart';
import 'ramadan.dart';

final ramadanAdjustProvider = Provider<int>((ref) => 0);

class RamadanScreen extends ConsumerWidget {
  const RamadanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final info = ramadanInfo(now, adjustDays: ref.watch(ramadanAdjustProvider));
    final log =
        ref.watch(ramadanLogProvider(info.hijriYear)).value ??
        const RamadanLog();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('رمضان ${info.hijriYear}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const RamadanHero(),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat('🌙', 'صمت', '${log.fasted.length}'),
              const SizedBox(width: 12),
              _Stat('🕌', 'تراويح', '${log.taraweeh.length}'),
              const SizedBox(width: 12),
              const _Stat('📖', 'الورد المقترح', '20 ص'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'أيام الشهر',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'دوسة: صمت ✓ • ضغطة طويلة: صليت التراويح 🕌',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var d = 1; d <= 30; d++)
                _DayCell(
                  day: d,
                  fasted: log.fasted.contains(d),
                  taraweeh: log.taraweeh.contains(d),
                  isToday: info.isRamadan && info.day == d,
                  future: !info.isRamadan || d > info.day,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setRamadanDay(
                      ref,
                      info.hijriYear,
                      d,
                      fasted: !log.fasted.contains(d),
                    );
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setRamadanDay(
                      ref,
                      info.hijriYear,
                      d,
                      taraweeh: !log.taraweeh.contains(d),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (info.isLastTen)
            Card(
              color: AppColors.gold200.withValues(alpha: 0.6),
              child: const ListTile(
                leading: Text('✨', style: TextStyle(fontSize: 28)),
                title: Text('العشر الأواخر'),
                subtitle: Text(
                  'اجتهد في القيام والدعاء، وتحرّى ليلة القدر في الليالي الوترية.',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// بطاقة رمضان: في رمضان السحور والإفطار بعدّاد، وقبله عدّاد لحد ما يبدأ
class RamadanHero extends ConsumerWidget {
  const RamadanHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final info = ramadanInfo(now, adjustDays: ref.watch(ramadanAdjustProvider));
    final times = ref.watch(todayPrayerTimesProvider);
    final text = Theme.of(context).textTheme;
    final fajr = times[PrayerName.fajr];
    final maghrib = times[PrayerName.maghrib];
    final imsak = fajr.subtract(const Duration(minutes: 10));

    String title, line1, line2;
    if (!info.isRamadan) {
      title = 'رمضان ${info.hijriYear}';
      line1 = 'فاضل ${info.daysUntilRamadan} يوم';
      line2 = 'اللهم بلّغنا رمضان 🤲';
    } else {
      title = 'اليوم ${info.day} من رمضان';
      if (now.isBefore(fajr)) {
        line1 =
            'الإمساك ${formatPrayerTime(imsak)} • الفجر ${formatPrayerTime(fajr)}';
        line2 = 'السحور ${formatCountdown(imsak.difference(now))}';
      } else if (now.isBefore(maghrib)) {
        line1 = 'الإفطار ${formatPrayerTime(maghrib)}';
        line2 = formatCountdown(maghrib.difference(now));
      } else {
        line1 = 'تقبّل الله صيامك 🌙';
        line2 = 'العيد بعد ${info.daysUntilEid} يوم';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emerald900, Color(0xFF14223A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  line1,
                  style: text.bodyLarge?.copyWith(color: Colors.white70),
                ),
                Text(
                  line2,
                  style: text.titleMedium?.copyWith(
                    color: AppColors.gold500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.emoji, this.label, this.value);
  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              '$emoji $value',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.fasted,
    required this.taraweeh,
    required this.isToday,
    required this.future,
    required this.onTap,
    required this.onLongPress,
  });

  final int day;
  final bool fasted;
  final bool taraweeh;
  final bool isToday;
  final bool future;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: future ? null : onTap,
      onLongPress: future ? null : onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: fasted
              ? AppColors.emerald500
              : future
              ? scheme.outlineVariant.withValues(alpha: 0.15)
              : scheme.outlineVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: isToday
              ? Border.all(color: AppColors.gold500, width: 2.5)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: fasted ? Colors.white : null,
              ),
            ),
            if (taraweeh)
              const Positioned(
                top: 2,
                left: 4,
                child: Text('🕌', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }
}
