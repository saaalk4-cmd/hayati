import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'session.dart';
import 'task.dart';

abstract class TasksRepository {
  Stream<List<HayatiTask>> watch();
  Future<void> add(String title, {String? dueDate});
  Future<void> addTask(HayatiTask task);
  Future<void> toggle(HayatiTask task);

  /// حفظ تعديلات المهمة (العنوان، الأولوية، المهام الفرعية، الملاحظات)
  Future<void> update(HayatiTask task);
  Future<void> delete(String id);
}

List<HayatiTask> _sorted(List<HayatiTask> list) => list
  ..sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.priority != b.priority) {
      return b.priority.index.compareTo(a.priority.index);
    }
    final ad = a.dueDate, bd = b.dueDate;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if ((ad == null) != (bd == null)) return ad == null ? 1 : -1;
    return b.createdAt.compareTo(a.createdAt);
  });

/// المهام على Firestore: users/{uid}/tasks
class FirestoreTasksRepository implements TasksRepository {
  FirestoreTasksRepository(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('tasks');

  @override
  Stream<List<HayatiTask>> watch() => _col.snapshots().map(
    (s) =>
        _sorted(s.docs.map((d) => HayatiTask.fromMap(d.id, d.data())).toList()),
  );

  @override
  Future<void> add(String title, {String? dueDate}) => addTask(
    HayatiTask(
      id: '',
      title: title,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    ),
  );

  @override
  Future<void> addTask(HayatiTask task) => _col.add(task.toMap());

  @override
  Future<void> toggle(HayatiTask task) async {
    await _col.doc(task.id).update({'done': !task.done});
    // المهمة المتكررة: لما تخلص بنضيف النسخة الجاية
    final next = task.done ? null : task.nextOccurrence('');
    if (next != null) await _col.add(next.toMap());
  }

  @override
  Future<void> update(HayatiTask task) =>
      _col.doc(task.id).set(task.toMap(), SetOptions(merge: true));

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

/// المهام على الجهاز (وضع الضيف)
class LocalTasksRepository implements TasksRepository {
  LocalTasksRepository(this.prefs);
  final SharedPreferences prefs;
  static const _key = 'local_tasks';
  final _controller = StreamController<List<HayatiTask>>.broadcast();

  List<HayatiTask> _read() {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final map = (jsonDecode(raw) as Map<String, dynamic>);
    return _sorted(
      map.entries
          .map(
            (e) => HayatiTask.fromMap(e.key, e.value as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Future<void> _write(List<HayatiTask> list) async {
    await prefs.setString(
      _key,
      jsonEncode({for (final t in list) t.id: t.toMap()}),
    );
    _controller.add(_read());
  }

  @override
  Stream<List<HayatiTask>> watch() async* {
    yield _read();
    yield* _controller.stream;
  }

  @override
  Future<void> add(String title, {String? dueDate}) => addTask(
    HayatiTask(
      id: '',
      title: title,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    ),
  );

  @override
  Future<void> addTask(HayatiTask task) {
    final t = HayatiTask.fromMap(const Uuid().v4(), task.toMap());
    return _write([..._read(), t]);
  }

  @override
  Future<void> toggle(HayatiTask task) {
    final next = task.done ? null : task.nextOccurrence(const Uuid().v4());
    return _write([
      for (final t in _read()) t.id == task.id ? t.copyWith(done: !t.done) : t,
      ?next,
    ]);
  }

  @override
  Future<void> update(HayatiTask task) =>
      _write([for (final t in _read()) t.id == task.id ? task : t]);

  @override
  Future<void> delete(String id) =>
      _write(_read().where((t) => t.id != id).toList());
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is UserSession) return FirestoreTasksRepository(session.uid);
  return LocalTasksRepository(ref.watch(sharedPrefsProvider));
});

final tasksProvider = StreamProvider<List<HayatiTask>>(
  (ref) => ref.watch(tasksRepositoryProvider).watch(),
);
