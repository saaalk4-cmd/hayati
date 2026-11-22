import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/session.dart';
import '../../data/user_store.dart';
import 'money_models.dart';

abstract class TransactionsRepository {
  Stream<List<Transaction>> watchMonth(String month);
  Future<void> add(Transaction t);
  Future<void> delete(String id);
}

List<Transaction> _sorted(List<Transaction> l) => l
  ..sort((a, b) {
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
  });

/// users/{uid}/transactions/{id}
class FirestoreTransactionsRepository implements TransactionsRepository {
  FirestoreTransactionsRepository(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('transactions');

  @override
  Stream<List<Transaction>> watchMonth(String month) => _col
      .where('month', isEqualTo: month)
      .snapshots()
      .map(
        (s) => _sorted(
          s.docs.map((d) => Transaction.fromMap(d.id, d.data())).toList(),
        ),
      );

  @override
  Future<void> add(Transaction t) => _col.add(t.toMap());

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class LocalTransactionsRepository implements TransactionsRepository {
  LocalTransactionsRepository(this.prefs);
  final SharedPreferences prefs;
  static const _key = 'local_transactions';
  static final _changes = StreamController<void>.broadcast();

  Map<String, Transaction> _read() {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in m.entries)
        e.key: Transaction.fromMap(e.key, e.value as Map<String, dynamic>),
    };
  }

  Future<void> _write(Map<String, Transaction> m) async {
    await prefs.setString(
      _key,
      jsonEncode({for (final e in m.entries) e.key: e.value.toMap()}),
    );
    _changes.add(null);
  }

  List<Transaction> _month(String month) =>
      _sorted(_read().values.where((t) => t.month == month).toList());

  @override
  Stream<List<Transaction>> watchMonth(String month) async* {
    yield _month(month);
    yield* _changes.stream.map((_) => _month(month));
  }

  @override
  Future<void> add(Transaction t) async {
    final id = const Uuid().v4();
    await _write({..._read(), id: Transaction.fromMap(id, t.toMap())});
  }

  @override
  Future<void> delete(String id) async => _write(_read()..remove(id));
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final s = ref.watch(sessionProvider);
  if (s is UserSession) return FirestoreTransactionsRepository(s.uid);
  return LocalTransactionsRepository(ref.watch(sharedPrefsProvider));
});

final monthTransactionsProvider =
    StreamProvider.family<List<Transaction>, String>(
      (ref, month) =>
          ref.watch(transactionsRepositoryProvider).watchMonth(month),
    );

/// إعدادات الفلوس: users/{uid}/money/settings
class MoneySettings {
  const MoneySettings({this.monthlyBudget, this.goals = const []});
  final double? monthlyBudget;
  final List<SavingsGoal> goals;
}

final moneySettingsProvider = StreamProvider<MoneySettings>((ref) {
  return ref.watch(userStoreProvider).watch('money', 'settings').map((d) {
    if (d == null) return const MoneySettings();
    final goals =
        (d['goals'] as List?)
            ?.map(
              (e) => SavingsGoal.fromMap((e as Map).cast<String, dynamic>()),
            )
            .toList() ??
        const [];
    return MoneySettings(
      monthlyBudget: (d['monthlyBudget'] as num?)?.toDouble(),
      goals: goals,
    );
  });
});

Future<void> setMonthlyBudget(WidgetRef ref, double? budget) => ref
    .read(userStoreProvider)
    .merge('money', 'settings', {'monthlyBudget': budget});

Future<void> saveGoals(WidgetRef ref, List<SavingsGoal> goals) =>
    ref.read(userStoreProvider).merge('money', 'settings', {
      'goals': goals.map((g) => g.toMap()).toList(),
    });
