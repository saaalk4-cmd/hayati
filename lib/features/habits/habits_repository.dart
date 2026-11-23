import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../../data/local_collection.dart';
import '../../data/session.dart';
import 'habit.dart';

abstract class HabitsRepository {
  Stream<List<Habit>> watch();
  Future<void> save(Habit habit);
  Future<void> setDone(Habit habit, DateTime day, bool done);
  Future<void> delete(String id);
}

List<Habit> _sorted(List<Habit> l) =>
    l..sort((a, b) => a.createdAt.compareTo(b.createdAt));

class FirestoreHabitsRepository implements HabitsRepository {
  FirestoreHabitsRepository(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('habits');

  @override
  Stream<List<Habit>> watch() => _col.snapshots().map(
    (s) => _sorted(s.docs.map((d) => Habit.fromMap(d.id, d.data())).toList()),
  );

  @override
  Future<void> save(Habit h) async {
    final data = h.toMap()..remove('done');
    if (h.id.isEmpty) {
      await _col.add({...data, 'done': <String, bool>{}});
    } else {
      await _col.doc(h.id).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> setDone(Habit h, DateTime day, bool done) =>
      _col.doc(h.id).update({
        'done.${HayatiDates.dayKey(day)}': done ? true : FieldValue.delete(),
      });

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class LocalHabitsRepository implements HabitsRepository {
  LocalHabitsRepository(SharedPreferences prefs)
    : _c = LocalJsonCollection<Habit>(
        prefs: prefs,
        key: 'local_habits',
        fromMap: Habit.fromMap,
        toMap: (h) => h.toMap(),
      );
  final LocalJsonCollection<Habit> _c;

  Habit _copy(
    Habit h, {
    required String id,
    Set<String>? done,
    DateTime? createdAt,
  }) => Habit(
    id: id,
    title: h.title,
    emoji: h.emoji,
    weekdays: h.weekdays,
    reminder: h.reminder,
    done: done ?? h.done,
    source: h.source,
    createdAt: createdAt ?? h.createdAt,
  );

  @override
  Stream<List<Habit>> watch() =>
      _c.watch().map((m) => _sorted(m.values.toList()));

  @override
  Future<void> save(Habit h) async {
    final all = _c.read();
    final id = h.id.isEmpty ? const Uuid().v4() : h.id;
    final old = all[id];
    all[id] = _copy(
      h,
      id: id,
      done: old?.done ?? const {},
      createdAt: old?.createdAt,
    );
    await _c.write(all);
  }

  @override
  Future<void> setDone(Habit h, DateTime day, bool done) async {
    final all = _c.read();
    final cur = all[h.id];
    if (cur == null) return;
    final key = HayatiDates.dayKey(day);
    final days = {...cur.done};
    done ? days.add(key) : days.remove(key);
    all[h.id] = _copy(cur, id: cur.id, done: days);
    await _c.write(all);
  }

  @override
  Future<void> delete(String id) async => _c.write(_c.read()..remove(id));
}

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  final s = ref.watch(sessionProvider);
  if (s is UserSession) return FirestoreHabitsRepository(s.uid);
  return LocalHabitsRepository(ref.watch(sharedPrefsProvider));
});

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitsRepositoryProvider).watch(),
);
