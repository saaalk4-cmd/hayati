import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/palettes.dart';
import '../../data/task.dart';
import '../../data/tasks_repository.dart';
import '../habits/habit.dart';
import '../habits/habits_repository.dart';
import '../journal/journal_repository.dart';
import '../money/money_analytics.dart';
import '../money/money_models.dart';
import '../money/money_repository.dart';
import '../money/money_screen.dart' show monthKey;
import '../tasks/task_detail_sheet.dart';

/// توحيد الكتابة العربية للبحث: الهمزات، والتاء المربوطة، والألف المقصورة، والتشكيل
String normalizeArabic(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[ً-ْـ]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .trim();

bool matchesQuery(String? text, String query) {
  if (text == null || text.isEmpty) return false;
  final q = normalizeArabic(query);
  if (q.isEmpty) return false;
  final t = normalizeArabic(text);
  return q.split(RegExp(r'\s+')).every(t.contains);
}

/// مقتطف حوالين أول كلمة متطابقة
String snippet(String text, String query, [int radius = 40]) {
  final flat = text.replaceAll('\n', ' ');
  final words = normalizeArabic(query).split(RegExp(r'\s+'));
  final norm = normalizeArabic(flat);
  final i = words.isEmpty ? -1 : norm.indexOf(words.first);
  if (i < 0 || flat.length <= radius * 2) {
    return flat.length > radius * 2
        ? '${flat.substring(0, radius * 2)}…'
        : flat;
  }
  final start = (i - radius).clamp(0, flat.length);
  final end = (i + radius).clamp(0, flat.length);
  return '${start > 0 ? '…' : ''}${flat.substring(start, end)}${end < flat.length ? '…' : ''}';
}

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final tasks = ref.watch(tasksProvider).value ?? const <HayatiTask>[];
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];
    final journal = ref.watch(journalProvider).value ?? const <JournalEntry>[];
    final txs = [
      for (final m in lastMonths(DateTime.now()).reversed)
        ...ref.watch(monthTransactionsProvider(monthKey(m))).value ??
            const <Transaction>[],
    ];

    final q = _q;
    final fTasks = tasks
        .where((t) => matchesQuery('${t.title} ${t.notes ?? ''}', q))
        .toList();
    final fHabits = habits.where((h) => matchesQuery(h.title, q)).toList();
    final fJournal = journal
        .where((e) => matchesQuery('${e.text} ${e.gratitude}', q))
        .toList();
    final fTx = txs
        .where(
          (t) => matchesQuery(
            '${t.note ?? ''} ${categoryById(t.category).name}',
            q,
          ),
        )
        .toList();
    final total = fTasks.length + fHabits.length + fJournal.length + fTx.length;

    Widget header(String title, int n, IconData icon) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.accent),
          const SizedBox(width: 6),
          Text(
            '$title ($n)',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'دوّر في كل حاجة…',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
        actions: [
          if (_q.isNotEmpty)
            IconButton(
              onPressed: () {
                _controller.clear();
                setState(() => _q = '');
              },
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: normalizeArabic(q).isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.manage_search, size: 64, color: p.accent),
                    const SizedBox(height: 12),
                    Text(
                      'دوّر في المهام، واليوميات، والعادات، والمصروفات',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge,
                    ),
                  ],
                ),
              ),
            )
          : total == 0
          ? Center(child: Text('مفيش نتايج لـ «$q»'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                if (fTasks.isNotEmpty) ...[
                  header('المهام', fTasks.length, Icons.check_circle_outline),
                  Card(
                    child: Column(
                      children: [
                        for (final t in fTasks.take(20))
                          ListTile(
                            leading: Icon(
                              t.done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: t.done ? p.accent : p.muted,
                            ),
                            title: Text(t.title),
                            subtitle: t.dueDate == null
                                ? null
                                : Text(t.dueDate!),
                            onTap: () => showTaskDetail(context, t),
                          ),
                      ],
                    ),
                  ),
                ],
                if (fHabits.isNotEmpty) ...[
                  header(
                    'العادات',
                    fHabits.length,
                    Icons.local_fire_department_outlined,
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final h in fHabits)
                          ListTile(
                            leading: Text(
                              h.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(h.title),
                            onTap: () => context.go('/more/habits/${h.id}'),
                          ),
                      ],
                    ),
                  ),
                ],
                if (fJournal.isNotEmpty) ...[
                  header('اليوميات', fJournal.length, Icons.menu_book_outlined),
                  Card(
                    child: Column(
                      children: [
                        for (final e in fJournal.take(20))
                          ListTile(
                            leading: Text(
                              e.mood == null ? '📝' : moodEmojis[e.mood]!,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(e.day),
                            subtitle: Text(
                              snippet(
                                matchesQuery(e.text, q) ? e.text : e.gratitude,
                                q,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => context.go('/more/journal/${e.day}'),
                          ),
                      ],
                    ),
                  ),
                ],
                if (fTx.isNotEmpty) ...[
                  header(
                    'المصروفات (آخر 6 شهور)',
                    fTx.length,
                    Icons.account_balance_wallet_outlined,
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final t in fTx.take(30))
                          ListTile(
                            leading: Icon(
                              categoryById(t.category).icon,
                              color: categoryById(t.category).color,
                            ),
                            title: Text(
                              t.note?.isNotEmpty == true
                                  ? t.note!
                                  : categoryById(t.category).name,
                            ),
                            subtitle: Text(t.date),
                            trailing: Text(
                              '${t.type == TxType.income ? '+' : '-'}${formatMoney(t.amount)}',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: p.text,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
