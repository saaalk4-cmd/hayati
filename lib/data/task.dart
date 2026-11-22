class HayatiTask {
  const HayatiTask({
    required this.id,
    required this.title,
    this.done = false,
    this.dueDate,
    this.notes,
    this.source = 'app',
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool done;

  /// yyyy-MM-dd أو null
  final String? dueDate;
  final String? notes;

  /// app | assistant
  final String source;
  final DateTime createdAt;

  HayatiTask copyWith({bool? done, String? title}) => HayatiTask(
        id: id,
        title: title ?? this.title,
        done: done ?? this.done,
        dueDate: dueDate,
        notes: notes,
        source: source,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'done': done,
        'dueDate': dueDate,
        'notes': notes,
        'source': source,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory HayatiTask.fromMap(String id, Map<String, dynamic> m) {
    final created = m['createdAt'];
    return HayatiTask(
      id: id,
      title: (m['title'] ?? '') as String,
      done: (m['done'] ?? false) as bool,
      dueDate: m['dueDate'] as String?,
      notes: m['notes'] as String?,
      source: (m['source'] ?? 'app') as String,
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : DateTime.now(),
    );
  }
}
