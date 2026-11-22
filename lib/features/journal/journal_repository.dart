import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/session.dart';

/// مزاج اليوم من 1 (وحش) لـ 5 (ممتاز)
const moodEmojis = {1: '😞', 2: '😕', 3: '😐', 4: '🙂', 5: '😄'};
const moodNames = {
  1: 'وحش',
  2: 'مش أحسن حاجة',
  3: 'عادي',
  4: 'كويس',
  5: 'ممتاز',
};

/// يومية واحدة لكل يوم: users/{uid}/journal/{yyyy-MM-dd}
class JournalEntry {
  const JournalEntry({
    required this.day,
    this.mood,
    this.text = '',
    this.gratitude = '',
    required this.updatedAt,
  });

  final String day;
  final int? mood;
  final String text;

  /// «حاجة حلوة حصلت النهارده / الحمد لله على...»
  final String gratitude;
  final DateTime updatedAt;

  bool get isEmpty =>
      mood == null && text.trim().isEmpty && gratitude.trim().isEmpty;

  Map<String, dynamic> toMap() => {
    'day': day,
    'mood': mood,
    'text': text,
    'gratitude': gratitude,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory JournalEntry.fromMap(String day, Map<String, dynamic> m) {
    final u = m['updatedAt'];
    return JournalEntry(
      day: day,
      mood: (m['mood'] as num?)?.toInt(),
      text: (m['text'] as String?) ?? '',
      gratitude: (m['gratitude'] as String?) ?? '',
      updatedAt: u is int
          ? DateTime.fromMillisecondsSinceEpoch(u)
          : DateTime.now(),
    );
  }
}

abstract class JournalRepository {
  Stream<List<JournalEntry>> watchAll();
  Future<void> save(JournalEntry e);
  Future<void> delete(String day);
}

List<JournalEntry> _sorted(List<JournalEntry> l) =>
    l..sort((a, b) => b.day.compareTo(a.day));

class FirestoreJournalRepository implements JournalRepository {
  FirestoreJournalRepository(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('journal');

  @override
  Stream<List<JournalEntry>> watchAll() => _col
      .orderBy('day', descending: true)
      .limit(400)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => JournalEntry.fromMap(d.id, d.data())).toList(),
      );

  @override
  Future<void> save(JournalEntry e) => _col.doc(e.day).set(e.toMap());

  @override
  Future<void> delete(String day) => _col.doc(day).delete();
}

class LocalJournalRepository implements JournalRepository {
  LocalJournalRepository(this.prefs);
  final SharedPreferences prefs;
  static const _key = 'local_journal';
  static final _changes = StreamController<void>.broadcast();

  Map<String, JournalEntry> _read() {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in m.entries)
        e.key: JournalEntry.fromMap(e.key, e.value as Map<String, dynamic>),
    };
  }

  Future<void> _write(Map<String, JournalEntry> m) async {
    await prefs.setString(
      _key,
      jsonEncode({for (final e in m.entries) e.key: e.value.toMap()}),
    );
    _changes.add(null);
  }

  @override
  Stream<List<JournalEntry>> watchAll() async* {
    yield _sorted(_read().values.toList());
    yield* _changes.stream.map((_) => _sorted(_read().values.toList()));
  }

  @override
  Future<void> save(JournalEntry e) => _write({..._read(), e.day: e});

  @override
  Future<void> delete(String day) => _write(_read()..remove(day));
}

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  final s = ref.watch(sessionProvider);
  if (s is UserSession) return FirestoreJournalRepository(s.uid);
  return LocalJournalRepository(ref.watch(sharedPrefsProvider));
});

final journalProvider = StreamProvider<List<JournalEntry>>(
  (ref) => ref.watch(journalRepositoryProvider).watchAll(),
);

/// «في مثل هذا اليوم»: يوميات نفس اليوم من شهر/سنة فاتت
List<(String, JournalEntry)> onThisDay(List<JournalEntry> all, DateTime today) {
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final targets = <String, String>{};
  void add(DateTime d, String label) {
    // DateTime بيعدّي الشهر لو اليوم مش موجود (31 فبراير = 3 مارس)، فنتجاهله
    if (d.day == today.day) targets[key(d)] = label;
  }

  add(DateTime(today.year, today.month - 1, today.day), 'من شهر');
  add(DateTime(today.year, today.month - 6, today.day), 'من 6 شهور');
  for (var y = 1; y <= 5; y++) {
    add(
      DateTime(today.year - y, today.month, today.day),
      y == 1 ? 'من سنة' : 'من $y سنين',
    );
  }
  return [
    for (final e in all)
      if (targets.containsKey(e.day) && !e.isEmpty) (targets[e.day]!, e),
  ];
}
