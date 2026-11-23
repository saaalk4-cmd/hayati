import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/palettes.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/motion.dart';
import '../journal/journal_repository.dart';
import '../money/money_models.dart';
import '../stats/stats.dart';

/// أسئلة التأمل الأسبوعية
const reviewQuestions = [
  'إيه أحسن حاجة عملتها الأسبوع ده؟',
  'إيه اللي كان ممكن يبقى أحسن؟',
  'إيه أهم 3 حاجات عايز تعملها الأسبوع الجاي؟',
];

/// نص المراجعة اللي بيتحفظ في يوميات النهارده (بيتضاف على الموجود)
String buildReviewText(List<String> answers) {
  final b = StringBuffer('📝 مراجعة الأسبوع');
  for (var i = 0; i < reviewQuestions.length; i++) {
    final a = i < answers.length ? answers[i].trim() : '';
    if (a.isEmpty) continue;
    b.write('\n\n${reviewQuestions[i]}\n$a');
  }
  return b.toString();
}

/// يوم الجمعة أو السبت: وقت المراجعة
bool isReviewTime(DateTime d) =>
    d.weekday == DateTime.friday || d.weekday == DateTime.saturday;

class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  final _answers = [for (final _ in reviewQuestions) TextEditingController()];
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final text = buildReviewText([for (final c in _answers) c.text]);
    if (_answers.every((c) => c.text.trim().isEmpty)) return;
    setState(() => _saving = true);
    final repo = ref.read(journalRepositoryProvider);
    final day = HayatiDates.dayKey(DateTime.now());
    final journal = ref.read(journalProvider).value ?? const <JournalEntry>[];
    final old = journal.where((e) => e.day == day).firstOrNull;
    await repo.save(
      JournalEntry(
        day: day,
        mood: old?.mood,
        gratitude: old?.gratitude ?? '',
        text: old == null || old.text.trim().isEmpty
            ? text
            : '${old.text}\n\n$text',
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showCelebration(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اتحفظت في يومياتك ✨ أسبوع جديد موفّق')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final s = ref.watch(statsProvider(StatsPeriod.week));

    Widget tile(String emoji, String value, String label) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
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
      appBar: AppBar(title: const Text('مراجعة الأسبوع')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: staggered([
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: p.hero,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أسبوعك في سطور',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${arFormat('d MMMM', s.days.first)} – ${arFormat('d MMMM', s.days.last)}',
                  style: text.bodyMedium?.copyWith(color: p.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              tile('🕌', '${(s.prayerRate * 100).round()}%', 'الصلوات'),
              tile('✅', '${s.tasksDone}', 'مهام خلصت'),
              tile('🔥', '${(s.habitRate * 100).round()}%', 'العادات'),
            ],
          ),
          Row(
            children: [
              tile('📖', '${s.quranPages}', 'صفحة قرآن'),
              tile('💸', formatMoney(s.spent.roundToDouble()), 'صرفت'),
              tile(
                s.avgMood == null
                    ? '🙂'
                    : moodEmojis[s.avgMood!.round().clamp(1, 5)]!,
                s.avgMood == null ? '—' : s.avgMood!.toStringAsFixed(1),
                'المزاج',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'وقفة مع نفسك',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            'إجاباتك بتتحفظ في يوميات النهارده',
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < reviewQuestions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _answers[i],
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: reviewQuestions[i],
                  alignLabelWithHint: true,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.bookmark_added_outlined),
            label: const Text('احفظ المراجعة'),
          ),
        ]),
      ),
    );
  }
}
