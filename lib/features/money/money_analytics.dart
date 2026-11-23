import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/palettes.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/motion.dart';
import 'money_models.dart';
import 'money_repository.dart';
import 'money_screen.dart' show monthKey;

/// آخر [n] شهور من الأقدم للأحدث (yyyy-MM)
List<DateTime> lastMonths(DateTime now, [int n = 6]) => [
  for (var i = n - 1; i >= 0; i--) DateTime(now.year, now.month - i),
];

/// متوسط المصروف في اليوم: الشهر الحالي على الأيام اللي فاتت بس
double dailyAverage(double spent, DateTime month, DateTime now) {
  final isCurrent = month.year == now.year && month.month == now.month;
  final days = isCurrent
      ? now.day
      : DateTime(month.year, month.month + 1, 0).day;
  return days == 0 ? 0 : spent / days;
}

class MoneyAnalyticsScreen extends ConsumerWidget {
  const MoneyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final months = lastMonths(now);
    final data = [
      for (final m in months)
        MonthSummary(
          ref.watch(monthTransactionsProvider(monthKey(m))).value ?? const [],
        ),
    ];
    final current = data.last;
    final all = MonthSummary([for (final d in data) ...d.transactions]);
    final top = all.byCategory();
    final maxSpent = data.fold<double>(0, (a, b) => b.spent > a ? b.spent : a);
    final nonEmpty = data.where((d) => d.spent > 0).toList();
    final avgMonth = nonEmpty.isEmpty
        ? 0.0
        : nonEmpty.fold<double>(0, (a, b) => a + b.spent) / nonEmpty.length;
    final avgDay = dailyAverage(current.spent, months.last, now);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    Widget stat(String label, String value, IconData icon) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: p.accent),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(
                  value,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('تحليلات الفلوس')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: staggered([
          Row(
            children: [
              stat(
                'متوسط اليوم',
                formatMoney(avgDay.roundToDouble()),
                Icons.today,
              ),
              stat(
                'متوقع آخر الشهر',
                formatMoney((avgDay * daysInMonth).roundToDouble()),
                Icons.trending_up,
              ),
              stat(
                'متوسط الشهر',
                formatMoney(avgMonth.roundToDouble()),
                Icons.calendar_month,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المصروف في آخر 6 شهور',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 170,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < months.length; i++)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FittedBox(
                                  child: Text(
                                    data[i].spent == 0
                                        ? ''
                                        : formatMoney(
                                            data[i].spent.roundToDouble(),
                                          ),
                                    style: text.labelSmall?.copyWith(
                                      color: p.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    end: maxSpent == 0
                                        ? 0
                                        : data[i].spent / maxSpent,
                                  ),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, _) => Container(
                                    height: 4 + 110 * v,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: i == months.length - 1
                                            ? [
                                                p.accent.withValues(alpha: 0.7),
                                                p.accent,
                                              ]
                                            : [
                                                p.primary.withValues(
                                                  alpha: 0.5,
                                                ),
                                                p.primary,
                                              ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  child: Text(
                                    arFormat('MMM', months[i]),
                                    style: text.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (top.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أكتر حاجات صرفت عليها',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'آخر 6 شهور',
                      style: text.bodySmall?.copyWith(color: p.muted),
                    ),
                    const SizedBox(height: 8),
                    for (final (c, v) in top.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: c.color.withValues(alpha: 0.2),
                              child: Icon(c.icon, size: 18, color: c.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(c.name)),
                                      Text(
                                        '${formatMoney(v.roundToDouble())} • ${(v / all.spent * 100).round()}%',
                                        style: text.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: v / top.first.$2,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(6),
                                    color: c.color,
                                    backgroundColor: c.color.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'سجّل مصروفاتك وهتلاقي التحليل هنا',
                textAlign: TextAlign.center,
              ),
            ),
          if (data.length >= 2 && data[data.length - 2].spent > 0)
            Card(
              child: ListTile(
                leading: Icon(
                  current.spent <= data[data.length - 2].spent
                      ? Icons.thumb_up_alt_outlined
                      : Icons.warning_amber_rounded,
                  color: p.accent,
                ),
                title: Text(
                  current.spent <= data[data.length - 2].spent
                      ? 'صرفت لحد دلوقتي أقل من الشهر اللي فات كله 👏'
                      : 'عدّيت مصروف الشهر اللي فات بـ ${formatMoney((current.spent - data[data.length - 2].spent).roundToDouble())}',
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
