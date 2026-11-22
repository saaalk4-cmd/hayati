import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../lock/lock_service.dart';
import 'journal_repository.dart';

/// اليوميات بتتقفل بالبصمة/الرمز لو قفل التطبيق مفعّل
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    final lock = ref.read(lockProvider);
    _unlocked = !lock.enabled;
    if (!_unlocked && lock.biometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  Future<void> _unlock() async {
    final ok = await ref.read(lockProvider.notifier).unlockWithBiometrics();
    if (ok && mounted) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      final lock = ref.watch(lockProvider);
      return Scaffold(
        appBar: AppBar(title: const Text('يومياتي')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: AppColors.gold500,
              ),
              const SizedBox(height: 12),
              const Text('يومياتك مقفولة'),
              const SizedBox(height: 16),
              if (lock.biometrics)
                FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('افتح بالبصمة'),
                )
              else
                FilledButton(
                  onPressed: () async {
                    final ok = await _askPin(context);
                    if (ok && mounted) setState(() => _unlocked = true);
                  },
                  child: const Text('افتح بالرمز'),
                ),
            ],
          ),
        ),
      );
    }

    final entries = ref.watch(journalProvider);
    final today = HayatiDates.dayKey(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('يومياتي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/journal/$today'),
        icon: const Icon(Icons.edit),
        label: const Text('اكتب النهارده'),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذّر التحميل')),
        data: (list) {
          final memories = onThisDay(list, DateTime.now());
          final written = list.where((e) => !e.isEmpty).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _MoodWeek(entries: list),
              const SizedBox(height: 12),
              for (final (label, e) in memories)
                Card(
                  color: AppColors.gold200.withValues(alpha: 0.6),
                  child: ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: AppColors.gold700,
                    ),
                    title: Text('في مثل هذا اليوم • $label'),
                    subtitle: Text(
                      '${e.mood == null ? '' : '${moodEmojis[e.mood]} '}${e.text.isEmpty ? e.gratitude : e.text}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => context.push('/more/journal/${e.day}'),
                  ),
                ),
              if (written.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'اكتب يومك، حتى لو سطر واحد.\nبعد سنة هتفرح إنك كتبت 🌿',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final e in written)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Text(
                      e.mood == null ? '📝' : moodEmojis[e.mood]!,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(
                      DateFormat(
                        'EEEE d MMMM y',
                        'ar',
                      ).format(DateTime.parse(e.day)),
                    ),
                    subtitle: Text(
                      e.text.isEmpty ? e.gratitude : e.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => context.push('/more/journal/${e.day}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _askPin(BuildContext context) async {
    final c = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('رمز الدخول'),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('فتح'),
          ),
        ],
      ),
    );
    c.dispose();
    if (pin == null) return false;
    return ref.read(lockProvider.notifier).unlockWithPin(pin);
  }
}

/// مزاج آخر 7 أيام
class _MoodWeek extends StatelessWidget {
  const _MoodWeek({required this.entries});
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final e in entries) e.day: e};
    final today = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مزاجك الأسبوع ده',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 6; i >= 0; i--)
                  Builder(
                    builder: (context) {
                      final d = today.subtract(Duration(days: i));
                      final e = byDay[HayatiDates.dayKey(d)];
                      return Column(
                        children: [
                          Text(
                            e?.mood == null ? '·' : moodEmojis[e!.mood]!,
                            style: const TextStyle(fontSize: 24),
                          ),
                          Text(
                            DateFormat('E', 'ar').format(d),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
