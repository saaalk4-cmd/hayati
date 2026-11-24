import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

/// تخزين بسيط لمستندات المستخدم: users/{uid}/{collection}/{doc}
/// على Firestore للمستخدم المسجّل، وعلى الجهاز في وضع الضيف.
abstract class UserStore {
  Stream<Map<String, dynamic>?> watch(String collection, String doc);
  Future<Map<String, dynamic>?> get(String collection, String doc);

  /// دمج الحقول مع الموجود (merge)
  Future<void> merge(String collection, String doc, Map<String, dynamic> data);
}

class FirestoreUserStore implements UserStore {
  FirestoreUserStore(this.uid);
  final String uid;

  DocumentReference<Map<String, dynamic>> _ref(String c, String d) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(c)
          .doc(d);

  @override
  Stream<Map<String, dynamic>?> watch(String c, String d) =>
      _ref(c, d).snapshots().map((s) => s.data());

  @override
  Future<Map<String, dynamic>?> get(String c, String d) async =>
      (await _ref(c, d).get()).data();

  @override
  Future<void> merge(String c, String d, Map<String, dynamic> data) =>
      _ref(c, d).set(data, SetOptions(merge: true));
}

class LocalUserStore implements UserStore {
  LocalUserStore(this.prefs);
  final SharedPreferences prefs;
  static final _changes = StreamController<String>.broadcast();

  /// بعد ما بيانات اتكتبت من برّه (زرار في إشعار): نخلّي الشاشات تقرا من جديد
  static void refreshAll(Iterable<String> keys) => keys.forEach(_changes.add);

  String _key(String c, String d) => 'store/$c/$d';

  Map<String, dynamic>? _read(String key) {
    final raw = prefs.getString(key);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Stream<Map<String, dynamic>?> watch(String c, String d) async* {
    final key = _key(c, d);
    yield _read(key);
    yield* _changes.stream.where((k) => k == key).map(_read);
  }

  @override
  Future<Map<String, dynamic>?> get(String c, String d) async =>
      _read(_key(c, d));

  @override
  Future<void> merge(String c, String d, Map<String, dynamic> data) async {
    final key = _key(c, d);
    await prefs.setString(key, jsonEncode(deepMerge(_read(key) ?? {}, data)));
    _changes.add(key);
  }
}

/// دمج عميق زي Firestore merge: الخرايط المتداخلة بتتدمج مش بتتستبدل
/// (مثلًا سجل القرآن {اليوم: صفحات} بيحتفظ بالأيام القديمة)
Map<String, dynamic> deepMerge(
  Map<String, dynamic> base,
  Map<String, dynamic> update,
) {
  final out = {...base};
  for (final e in update.entries) {
    final old = out[e.key];
    if (old is Map && e.value is Map) {
      out[e.key] = deepMerge(
        old.cast<String, dynamic>(),
        (e.value as Map).cast<String, dynamic>(),
      );
    } else {
      out[e.key] = e.value;
    }
  }
  return out;
}

final userStoreProvider = Provider<UserStore>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is UserSession) return FirestoreUserStore(session.uid);
  return LocalUserStore(ref.watch(sharedPrefsProvider));
});
