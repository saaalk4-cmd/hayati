/// قوائم المهام الجاهزة
const taskLists = ['عام', 'شغل', 'بيت', 'مشتريات', 'دراسة'];

/// تكرار المهمة
enum TaskRepeat { none, daily, weekly, monthly }

extension TaskRepeatAr on TaskRepeat {
  String get ar => const {
    TaskRepeat.none: 'مرة واحدة',
    TaskRepeat.daily: 'كل يوم',
    TaskRepeat.weekly: 'كل أسبوع',
    TaskRepeat.monthly: 'كل شهر',
  }[this]!;
}

class HayatiTask {
  const HayatiTask({
    required this.id,
    required this.title,
    this.done = false,
    this.dueDate,
    this.notes,
    this.list = 'عام',
    this.repeat = TaskRepeat.none,
    this.remindAt,
    this.source = 'app',
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool done;

  /// yyyy-MM-dd أو null
  final String? dueDate;
  final String? notes;
  final String list;
  final TaskRepeat repeat;

  /// وقت التذكير (لو موجود)
  final DateTime? remindAt;

  /// app | assistant
  final String source;
  final DateTime createdAt;

  DateTime? get dueDateTime =>
      dueDate == null ? null : DateTime.tryParse(dueDate!);

  HayatiTask copyWith({bool? done, String? title}) => HayatiTask(
    id: id,
    title: title ?? this.title,
    done: done ?? this.done,
    dueDate: dueDate,
    notes: notes,
    list: list,
    repeat: repeat,
    remindAt: remindAt,
    source: source,
    createdAt: createdAt,
  );

  /// النسخة الجاية من مهمة متكررة
  HayatiTask? nextOccurrence(String newId) {
    if (repeat == TaskRepeat.none) return null;
    final base = dueDateTime ?? DateTime.now();
    DateTime shift(DateTime d) => switch (repeat) {
      TaskRepeat.daily => d.add(const Duration(days: 1)),
      TaskRepeat.weekly => d.add(const Duration(days: 7)),
      TaskRepeat.monthly => DateTime(
        d.year,
        d.month + 1,
        d.day,
        d.hour,
        d.minute,
      ),
      TaskRepeat.none => d,
    };
    final next = shift(base);
    String two(int v) => v.toString().padLeft(2, '0');
    return HayatiTask(
      id: newId,
      title: title,
      dueDate: '${next.year}-${two(next.month)}-${two(next.day)}',
      notes: notes,
      list: list,
      repeat: repeat,
      remindAt: remindAt == null ? null : shift(remindAt!),
      source: source,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'done': done,
    'dueDate': dueDate,
    'notes': notes,
    'list': list,
    'repeat': repeat.name,
    'remindAt': remindAt?.millisecondsSinceEpoch,
    'source': source,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory HayatiTask.fromMap(String id, Map<String, dynamic> m) {
    final created = m['createdAt'];
    final remind = m['remindAt'];
    return HayatiTask(
      id: id,
      title: (m['title'] ?? '') as String,
      done: (m['done'] ?? false) as bool,
      dueDate: m['dueDate'] as String?,
      notes: m['notes'] as String?,
      list: (m['list'] as String?) ?? 'عام',
      repeat: TaskRepeat.values.firstWhere(
        (r) => r.name == m['repeat'],
        orElse: () => TaskRepeat.none,
      ),
      remindAt: remind is int
          ? DateTime.fromMillisecondsSinceEpoch(remind)
          : null,
      source: (m['source'] ?? 'app') as String,
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : DateTime.now(),
    );
  }
}
