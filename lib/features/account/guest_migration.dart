import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/session.dart';

/// المفاتيح اللي وضع الضيف بيخزن فيها، والمجموعة المقابلة على Firestore
const _collectionKeys = {
  'local_tasks': 'tasks',
  'local_habits': 'habits',
  'local_transactions': 'transactions',
  'local_journal': 'journal',
};

bool hasGuestData(SharedPreferences prefs) => prefs.getKeys().any(
  (k) => _collectionKeys.containsKey(k) || k.startsWith('store/'),
);

/// بينقل كل بيانات وضع الضيف لحساب المستخدم، وبعدين يمسحها من الجهاز.
/// بيرجّع عدد العناصر اللي اتنقلت.
Future<int> migrateGuestData(String uid, SharedPreferences prefs) async {
  final user = FirebaseFirestore.instance.collection('users').doc(uid);
  var count = 0;
  var batch = FirebaseFirestore.instance.batch();
  var ops = 0;

  Future<void> add(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    batch.set(ref, data, SetOptions(merge: true));
    count++;
    if (++ops >= 400) {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      ops = 0;
    }
  }

  for (final e in _collectionKeys.entries) {
    final raw = prefs.getString(e.key);
    if (raw == null) continue;
    final items = jsonDecode(raw) as Map<String, dynamic>;
    for (final item in items.entries) {
      await add(
        user.collection(e.value).doc(item.key),
        (item.value as Map).cast<String, dynamic>(),
      );
    }
  }
  // مستندات UserStore: store/{collection}/{doc}
  for (final k in prefs.getKeys().where((k) => k.startsWith('store/'))) {
    final parts = k.split('/');
    final raw = prefs.getString(k);
    if (parts.length != 3 || raw == null) continue;
    await add(
      user.collection(parts[1]).doc(parts[2]),
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }
  if (ops > 0) await batch.commit();

  for (final k in prefs.getKeys().toList()) {
    if (_collectionKeys.containsKey(k) || k.startsWith('store/')) {
      await prefs.remove(k);
    }
  }
  return count;
}

/// هل نعرض اقتراح نقل البيانات؟ (مستخدم مسجّل + فيه بيانات ضيف على الجهاز)
class GuestMigrationController extends Notifier<bool> {
  @override
  bool build() {
    final session = ref.watch(sessionProvider);
    return session is UserSession &&
        hasGuestData(ref.read(sharedPrefsProvider));
  }

  Future<int> migrate() async {
    final session = ref.read(sessionProvider);
    if (session is! UserSession) return 0;
    final n = await migrateGuestData(
      session.uid,
      ref.read(sharedPrefsProvider),
    );
    state = false;
    return n;
  }

  Future<void> dismiss() async {
    // المستخدم مش عايز ينقل: نمسح بيانات الضيف من الجهاز
    final prefs = ref.read(sharedPrefsProvider);
    for (final k in prefs.getKeys().toList()) {
      if (_collectionKeys.containsKey(k) || k.startsWith('store/')) {
        await prefs.remove(k);
      }
    }
    state = false;
  }
}

final guestMigrationProvider = NotifierProvider<GuestMigrationController, bool>(
  GuestMigrationController.new,
);
