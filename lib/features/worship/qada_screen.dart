import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/sound/sfx.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/motion.dart';
import 'prayer_service.dart';
import 'qada.dart';

class QadaScreen extends ConsumerWidget {
  const QadaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(qadaProvider).value ?? const QadaState();
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('قضاء الصلوات')),
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
            child: Column(
              children: [
                Text(
                  s.totalOwed == 0
                      ? 'مفيش صلوات فايتة متسجلة'
                      : 'فاضل ${s.totalOwed} صلاة',
                  style: text.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: s.progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: Colors.white24,
                  color: p.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  s.totalOwed == 0
                      ? (s.totalDone > 0
                            ? 'قضيت ${s.totalDone} صلاة، تقبّل الله 🤲'
                            : 'لو عليك صلوات فايتة، ابدأ بتقدير تحت')
                      : 'قضيت ${s.totalDone} • بالمعدل ده هتخلص في حوالي ${s.daysToFinish} يوم',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: p.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (s.totalOwed > 0)
            FilledButton.icon(
              onPressed: () {
                SoundFx.play(Sfx.done);
                logQada(ref, s);
                if (s.totalOwed <= 5) showCelebration(context);
              },
              icon: const Icon(Icons.check),
              label: const Text('قضيت يوم كامل (5 صلوات)'),
            ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final pr in PrayerName.values)
                  ListTile(
                    title: Text(
                      pr.ar,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('قضيت ${s.done[pr] ?? 0}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تعديل العدد',
                          onPressed: () =>
                              _edit(context, ref, pr, s.owed[pr] ?? 0),
                          icon: Text(
                            '${s.owed[pr] ?? 0}',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: (s.owed[pr] ?? 0) == 0
                              ? null
                              : () {
                                  SoundFx.play(Sfx.tick);
                                  logQada(ref, s, prayer: pr);
                                },
                          child: const Text('قضيتها'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('تقدير مبدئي'),
                  subtitle: const Text(
                    'لو مش عارف العدد بالظبط، قدّر بالأيام أو السنين',
                  ),
                  onTap: () => _estimate(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('هدفي في اليوم'),
                  trailing: DropdownButton<int>(
                    value: s.dailyGoal,
                    underline: const SizedBox(),
                    items: [
                      for (final g in [1, 2, 3, 5])
                        DropdownMenuItem(
                          value: g,
                          child: Text(g == 1 ? 'يوم واحد' : '$g أيام'),
                        ),
                    ],
                    onChanged: (g) => g == null ? null : setQadaGoal(ref, g),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'العدد ده للمتابعة بس. لو عندك سؤال فقهي عن القضاء ارجع لأهل العلم.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    PrayerName pr,
    int current,
  ) async {
    final c = TextEditingController(text: '$current');
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('صلاة ${pr.ar} الفايتة'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(d, int.tryParse(c.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v != null) await setQadaOwed(ref, pr, v);
  }

  Future<void> _estimate(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    var unit = 365;
    final v = await showDialog<int>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: const Text('تقدير الصلوات الفايتة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'العدد'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('أيام')),
                  ButtonSegment(value: 30, label: Text('شهور')),
                  ButtonSegment(value: 365, label: Text('سنين')),
                ],
                selected: {unit},
                onSelectionChanged: (s) => setState(() => unit = s.first),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                final n = int.tryParse(c.text);
                Navigator.pop(d, n == null ? null : n * unit);
              },
              child: const Text('احسب'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    if (v != null && v > 0) await setQadaEstimate(ref, v);
  }
}
