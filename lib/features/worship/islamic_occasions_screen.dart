import 'package:material_ui/material_ui.dart';

import '../../core/theme/palettes.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/motion.dart';
import 'islamic_occasions.dart';

class IslamicOccasionsScreen extends StatelessWidget {
  const IslamicOccasionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final list = upcomingIslamicOccasions(now);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final next = list.first;

    return Scaffold(
      appBar: AppBar(title: const Text('المناسبات الإسلامية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: staggered([
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: p.hero,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.cardBorder),
            ),
            child: Row(
              children: [
                Text(next.occasion.emoji, style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أقرب مناسبة',
                        style: text.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      Text(
                        next.occasion.name,
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        next.daysFrom(now) == 0
                            ? 'النهارده 🎉'
                            : 'بعد ${next.daysFrom(now)} يوم',
                        style: text.titleMedium?.copyWith(
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final o in list)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Text(
                  o.occasion.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(
                  o.occasion.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  [
                    arFormat('EEEE d MMMM y', o.date),
                    HayatiDates.hijri(o.date),
                    if (o.occasion.fasting) 'صيام مستحب',
                    ?o.occasion.note,
                  ].join(' • '),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: o.daysFrom(now) <= 7
                        ? p.accent
                        : p.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    o.daysFrom(now) == 0
                        ? 'النهارده'
                        : '${o.daysFrom(now)} يوم',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: o.daysFrom(now) <= 7 ? p.onAccent : p.accent,
                    ),
                  ),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'التواريخ محسوبة بالتقويم الهجري وممكن تفرق يوم حسب رؤية الهلال في بلدك. تقدر تعدّل التاريخ الهجري من إعدادات المواقيت.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }
}
