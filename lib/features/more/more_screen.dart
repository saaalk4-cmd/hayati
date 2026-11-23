import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/palettes.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/motion.dart';
import '../../data/session.dart';
import '../onboarding/onboarding_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const _sections = [
    (Icons.auto_awesome, 'مساعد حياتي', '/assistant'),
    (Icons.local_fire_department_outlined, 'عاداتي', '/more/habits'),
    (Icons.timer_outlined, 'وضع التركيز', '/focus'),
    (Icons.calendar_month_outlined, 'تقويمي', '/calendar'),
    (Icons.flag_outlined, 'أهدافي', '/goals'),
    (Icons.rate_review_outlined, 'مراجعة الأسبوع', '/review'),
    (Icons.book_outlined, 'يومياتي', '/more/journal'),
    (Icons.cake_outlined, 'مناسباتي وأهلي', '/more/occasions'),
    (Icons.insights_outlined, 'إحصائياتي', '/more/stats'),
    (Icons.nightlight_round, 'رمضان', '/worship/ramadan'),
    (Icons.settings_outlined, 'الإعدادات', '/more/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final localName = ref.watch(localNameProvider);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final name = session is UserSession
        ? (session.name ?? 'حسابي')
        : ((localName?.isNotEmpty ?? false) ? localName! : 'أهلًا بيك');

    return Scaffold(
      appBar: AppBar(
        title: const Text('المزيد'),
        actions: [
          IconButton(
            tooltip: 'بحث',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: staggered([
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: p.hero,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.cardBorder),
            ),
            child: Row(
              children: [
                const BrandMark(size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        session is UserSession
                            ? (session.email ?? 'حسابك متزامن ✓')
                            : 'وضع الضيف • بياناتك على الموبايل بس',
                        style: text.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (final (icon, title, path) in _sections)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(path),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: p.accent.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: p.accent, size: 22),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}
