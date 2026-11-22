import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
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
  LocalHabitsRepository(this.prefs);
  final SharedPreferences prefs;
  static const _key = 'local_habits';
  static final _changes = StreamController<void>.broadcast();

  Map<String, Habit> _read() {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in m.entries)
        e.key: Habit.fromMap(e.key, e.value as Map<String, dynamic>),
    };
  }

  Future<void> _write(Map<String, Habit> m) async {
    await prefs.setString(
      _key,
      jsonEncode({for (final e in m.entries) e.key: e.value.toMap()}),
    );
    _changes.add(null);
  }

  @override
  Stream<List<Habit>> watch() async* {
    yield _sorted(_read().values.toList());
    yield* _changes.stream.map((_) => _sorted(_read().values.toList()));
  }

  @override
  Future<void> save(Habit h) async {
    final all = _read();
    final id = h.id.isEmpty ? const Uuid().v4() : h.id;
    final old = all[id];
    all[id] = Habit(
      id: id,
      title: h.title,
      emoji: h.emoji,
      weekdays: h.weekdays,
      reminder: h.reminder,
      done: old?.done ?? const {},
      source: h.source,
      createdAt: old?.createdAt ?? h.createdAt,
    );
    await _write(all);
  }

  @override
  Future<void> setDone(Habit h, DateTime day, bool done) async {
    final all = _read();
    final cur = all[h.id];
    if (cur == null) return;
    final key = HayatiDates.dayKey(day);
    final days = {...cur.done};
    done ? days.add(key) : days.remove(key);
    all[h.id] = Habit(
      id: cur.id,
      title: cur.title,
      emoji: cur.emoji,
      weekdays: cur.weekdays,
      reminder: cur.reminder,
      done: days,
      source: cur.source,
      createdAt: cur.createdAt,
    );
    await _write(all);
  }

  @override
  Future<void> delete(String id) async {
    final all = _read()..remove(id);
    await _write(all);
  }
}

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  final s = ref.watch(sessionProvider);
  if (s is UserSession) return FirestoreHabitsRepository(s.uid);
  return LocalHabitsRepository(ref.watch(sharedPrefsProvider));
});

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitsRepositoryProvider).watch(),
);
