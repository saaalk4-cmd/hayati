import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/user_store.dart';

/// خطوة في هدف
class GoalStep {
  const GoalStep(this.title, {this.done = false});
  final String title;
  final bool done;

  GoalStep copyWith({bool? done}) => GoalStep(title, done: done ?? this.done);
  Map<String, dynamic> toMap() => {'t': title, 'd': done};
  factory GoalStep.fromMap(Map m) =>
      GoalStep('${m['t'] ?? ''}', done: m['d'] == true);
}

/// هدف طويل: users/{uid}/goals/state => {list: [...]}
class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.emoji = '🎯',
    this.steps = const [],
    this.deadline,
  });

  final String id;
  final String title;
  final String emoji;
  final List<GoalStep> steps;

  /// yyyy-MM-dd اختياري
  final String? deadline;

  int get doneCount => steps.where((s) => s.done).length;
  double get progress => steps.isEmpty ? 0 : doneCount / steps.length;
  bool get completed => steps.isNotEmpty && doneCount == steps.length;

  Goal copyWith({
    String? title,
    String? emoji,
    List<GoalStep>? steps,
    String? deadline,
  }) => Goal(
    id: id,
    title: title ?? this.title,
    emoji: emoji ?? this.emoji,
    steps: steps ?? this.steps,
    deadline: deadline ?? this.deadline,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'steps': [for (final s in steps) s.toMap()],
    if (deadline != null) 'deadline': deadline,
  };

  factory Goal.fromMap(Map m) => Goal(
    id: '${m['id']}',
    title: '${m['title'] ?? ''}',
    emoji: '${m['emoji'] ?? '🎯'}',
    steps: [
      for (final s in (m['steps'] as List? ?? const []))
        if (s is Map) GoalStep.fromMap(s),
    ],
    deadline: m['deadline'] as String?,
  );
}

/// أمثلة جاهزة تسهّل البداية
const goalTemplates = [
  (
    '📖',
    'أحفظ جزء عمّ',
    ['النبأ لحد البروج', 'الطارق لحد البلد', 'الشمس لحد الناس'],
  ),
  ('💰', 'أوفّر مبلغ', ['أحدد المبلغ', 'أحدد ميزانية شهرية', 'أحوّل أول قسط']),
  (
    '🎓',
    'أخلّص كورس',
    ['أختار الكورس', 'أخلّص نصه', 'أخلّصه كله', 'أطبّق مشروع'],
  ),
  ('🏃', 'ألتزم بالرياضة', ['أسبوع أول', 'شهر كامل', '3 شهور']),
];

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  return ref
      .watch(userStoreProvider)
      .watch('goals', 'state')
      .map(
        (d) => [
          for (final g in (d?['list'] as List? ?? const []))
            if (g is Map) Goal.fromMap(g),
        ],
      );
});

Future<void> saveGoals(UserStore store, List<Goal> goals) =>
    store.merge('goals', 'state', {
      'list': [for (final g in goals) g.toMap()],
    });

List<Goal> upsertGoal(List<Goal> goals, Goal g) {
  final i = goals.indexWhere((x) => x.id == g.id);
  if (i < 0) return [...goals, g];
  return [...goals]..[i] = g;
}

List<Goal> toggleStep(List<Goal> goals, String goalId, int index) => [
  for (final g in goals)
    if (g.id == goalId && index >= 0 && index < g.steps.length)
      g.copyWith(
        steps: [
          for (var i = 0; i < g.steps.length; i++)
            i == index
                ? g.steps[i].copyWith(done: !g.steps[i].done)
                : g.steps[i],
        ],
      )
    else
      g,
];
