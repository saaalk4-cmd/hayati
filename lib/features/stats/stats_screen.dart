import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../money/money_models.dart';
import 'stats.dart';
import '../../core/utils/date_utils.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsPeriod _period = StatsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(statsProvider(_period));
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائياتي'),
        actions: [
          IconButton(
            tooltip: 'شارك الملخص',
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: s.shareText(_period)),
            ),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<StatsPeriod>(
            segments: const [
              ButtonSegment(value: StatsPeriod.week, label: Text('آخر 7 أيام')),
              ButtonSegment(
                value: StatsPeriod.month,
                label: Text('آخر 30 يوم'),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (v) => setState(() => _period = v.first),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mosque, color: AppColors.emerald700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الصلوات',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${(s.prayerRate * 100).round()}%',
                        style: text.titleLarge?.copyWith(
                          color: AppColors.gold700,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.prayersDone} من ${s.prayersTotal} • في المسجد ${s.prayersMosque}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 90,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < s.days.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: s.days.length > 7 ? 1 : 6,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: 4 + 60 * s.prayersPerDay[i] / 5,
                                    decoration: BoxDecoration(
                                      color: s.prayersPerDay[i] == 5
                                          ? AppColors.gold500
                                          : AppColors.emerald500,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  if (s.days.length <= 7) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      arFormat('E', s.days[i]),
                                      style: text.labelSmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _Tile(
                '🔥',
                'العادات',
                '${(s.habitRate * 100).round()}%',
                'نسبة الالتزام',
              ),
              _Tile(
                '✅',
                'المهام',
                '${s.tasksDone}/${s.tasksTotal}',
                'خلصت من المطلوب',
              ),
              _Tile('📖', 'القرآن', '${s.quranPages}', 'صفحة'),
              _Tile(
                '💰',
                'المصروف',
                formatMoney(s.spent),
                'دخل: ${formatMoney(s.income)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (s.avgMood != null)
            Card(
              child: ListTile(
                leading: const Text('🙂', style: TextStyle(fontSize: 28)),
                title: const Text('متوسط مزاجك'),
                trailing: Text(
                  '${s.avgMood!.toStringAsFixed(1)} / 5',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(
              '/assistant?q=${Uri.encodeQueryComponent('لخّصلي أسبوعي وقولّي أتحسن في إيه')}',
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('حلّل أسبوعي مع المساعد'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: s.shareText(_period)),
            ),
            icon: const Icon(Icons.share),
            label: const Text('شارك ملخصك'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.emoji, this.title, this.value, this.caption);
  final String emoji;
  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$emoji $title',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              caption,
              style: text.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
