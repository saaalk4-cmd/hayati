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
  const MoneySettings({
    this.monthlyBudget,
    this.goals = const [],
    this.recurring = const [],
    this.recurringApplied = const {},
  });
  final double? monthlyBudget;
  final List<SavingsGoal> goals;

  /// مصروفات ثابتة بتتسجل لوحدها كل شهر
  final List<RecurringExpense> recurring;

  /// آخر شهر اتسجل فيه كل مصروف ثابت {id: yyyy-MM}
  final Map<String, String> recurringApplied;
}

/// مصروف ثابت شهري (فاتورة، إيجار، اشتراك...)
class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dayOfMonth,
  });
  final String id;
  final String title;
  final double amount;
  final String category;
  final int dayOfMonth;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category': category,
    'dayOfMonth': dayOfMonth,
  };

  factory RecurringExpense.fromMap(Map<String, dynamic> m) => RecurringExpense(
    id: m['id'] as String,
    title: (m['title'] as String?) ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    category: (m['category'] as String?) ?? 'bills',
    dayOfMonth: (m['dayOfMonth'] as num?)?.toInt() ?? 1,
  );
}

/// المصروفات الثابتة اللي معادها جه الشهر ده ولسه ما اتسجلتش
List<RecurringExpense> dueRecurring(MoneySettings s, DateTime now) {
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  return [
    for (final r in s.recurring)
      if (now.day >= r.dayOfMonth && s.recurringApplied[r.id] != month) r,
  ];
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
      recurring: [
        for (final e in (d['recurring'] as List?) ?? const [])
          RecurringExpense.fromMap((e as Map).cast<String, dynamic>()),
      ],
      recurringApplied: {
        for (final e in ((d['recurringApplied'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
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

Future<void> saveRecurring(WidgetRef ref, List<RecurringExpense> list) =>
    ref.read(userStoreProvider).merge('money', 'settings', {
      'recurring': list.map((r) => r.toMap()).toList(),
    });

/// بيسجّل المصروفات الثابتة اللي معادها جه (بيتنادى لما التطبيق يفتح)
Future<int> applyRecurring(
  UserStore store,
  TransactionsRepository repo,
  MoneySettings s,
  DateTime now,
) async {
  final due = dueRecurring(s, now);
  if (due.isEmpty) return 0;
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  // نعلّم الأول عشان منسجلش مرتين لو اتنادت تاني بسرعة
  await store.merge('money', 'settings', {
    'recurringApplied': {for (final r in due) r.id: month},
  });
  for (final r in due) {
    final day = r.dayOfMonth.clamp(1, DateTime(now.year, now.month + 1, 0).day);
    await repo.add(
      Transaction(
        id: '',
        type: TxType.expense,
        amount: r.amount,
        category: r.category,
        date: '$month-${day.toString().padLeft(2, '0')}',
        note: '🔁 ${r.title}',
        source: 'recurring',
        createdAt: DateTime.now(),
      ),
    );
  }
  return due.length;
}
