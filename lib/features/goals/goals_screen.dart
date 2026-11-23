import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/palettes.dart';
import '../../core/widgets/motion.dart';
import '../../data/user_store.dart';
import 'goals.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final active = goals.where((g) => !g.completed).toList();
    final done = goals.where((g) => g.completed).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('أهدافي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, goals),
        icon: const Icon(Icons.add),
        label: const Text('هدف جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: staggered([
          if (goals.isEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '🎯',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 8),
            Text(
              'حط هدف كبير وقسّمه خطوات صغيرة',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'ابدأ بمثال:',
              style: text.labelLarge?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in goalTemplates)
                  ActionChip(
                    avatar: Text(t.$1),
                    label: Text(t.$2),
                    onPressed: () => saveGoals(
                      ref.read(userStoreProvider),
                      upsertGoal(
                        goals,
                        Goal(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          title: t.$2,
                          emoji: t.$1,
                          steps: [for (final s in t.$3) GoalStep(s)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          for (final g in active) _GoalCard(goal: g, goals: goals),
          if (done.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '🏆 أهداف حققتها',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            for (final g in done) _GoalCard(goal: g, goals: goals),
          ],
        ]),
      ),
    );
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    List<Goal> goals, [
    Goal? goal,
  ]) async {
    final result = await showModalBottomSheet<Goal>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalEditor(goal: goal),
    );
    if (result == null) return;
    await saveGoals(ref.read(userStoreProvider), upsertGoal(goals, result));
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.goals});
  final Goal goal;
  final List<Goal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(goal.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${goal.doneCount} من ${goal.steps.length} خطوات'
                        '${goal.deadline != null ? ' • لحد ${goal.deadline}' : ''}',
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    final store = ref.read(userStoreProvider);
                    if (v == 'edit') {
                      await GoalsScreen._edit(context, ref, goals, goal);
                    } else {
                      await saveGoals(store, [
                        for (final g in goals)
                          if (g.id != goal.id) g,
                      ]);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'delete', child: Text('مسح')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: goal.progress),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    color: p.accent,
                    backgroundColor: p.accent.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < goal.steps.length; i++)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: goal.steps[i].done,
                title: Text(
                  goal.steps[i].title,
                  style: goal.steps[i].done
                      ? TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: p.muted,
                        )
                      : null,
                ),
                onChanged: (_) async {
                  final updated = toggleStep(goals, goal.id, i);
                  await saveGoals(ref.read(userStoreProvider), updated);
                  final g = updated.firstWhere((x) => x.id == goal.id);
                  if (g.completed && !goal.completed && context.mounted) {
                    showCelebration(context);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({this.goal});
  final Goal? goal;

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  static const _emojis = [
    '🎯',
    '📖',
    '💰',
    '🎓',
    '🏃',
    '🕌',
    '💼',
    '❤️',
    '🏠',
    '✈️',
  ];
  late final _title = TextEditingController(text: widget.goal?.title);
  late final _steps = TextEditingController(
    text: widget.goal?.steps.map((s) => s.title).join('\n'),
  );
  late String _emoji = widget.goal?.emoji ?? '🎯';
  late String? _deadline = widget.goal?.deadline;

  @override
  void dispose() {
    _title.dispose();
    _steps.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final old = {
      for (final s in widget.goal?.steps ?? const <GoalStep>[]) s.title: s.done,
    };
    final steps = [
      for (final l in _steps.text.split('\n'))
        if (l.trim().isNotEmpty)
          GoalStep(l.trim(), done: old[l.trim()] ?? false),
    ];
    Navigator.pop(
      context,
      Goal(
        id: widget.goal?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        emoji: _emoji,
        steps: steps,
        deadline: _deadline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.goal == null ? 'هدف جديد' : 'تعديل الهدف',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final e in _emojis)
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 18)),
                    selected: _emoji == e,
                    onSelected: (_) => setState(() => _emoji = e),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: widget.goal == null,
              decoration: const InputDecoration(labelText: 'الهدف'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _steps,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'الخطوات (كل خطوة في سطر)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event, color: p.accent),
              title: Text(
                _deadline == null ? 'من غير ميعاد' : 'لحد $_deadline',
              ),
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _deadline = null),
                      icon: const Icon(Icons.close),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  firstDate: now,
                  lastDate: DateTime(now.year + 10),
                  initialDate: now.add(const Duration(days: 30)),
                );
                if (d != null) {
                  setState(
                    () => _deadline =
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}
