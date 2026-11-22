import 'package:material_ui/material_ui.dart';

enum TxType { expense, income }

class MoneyCategory {
  const MoneyCategory(this.id, this.name, this.icon, this.color);
  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

/// نفس المعرّفات بيستخدمها المساعد على السيرفر
const expenseCategories = [
  MoneyCategory('food', 'أكل', Icons.restaurant, Color(0xFFE07A3F)),
  MoneyCategory(
    'transport',
    'مواصلات',
    Icons.directions_car,
    Color(0xFF3F7DE0),
  ),
  MoneyCategory('bills', 'فواتير', Icons.receipt_long, Color(0xFF8E5BD8)),
  MoneyCategory('home', 'بيت', Icons.home, Color(0xFF2E7D63)),
  MoneyCategory('health', 'صحة', Icons.medical_services, Color(0xFFD84B5B)),
  MoneyCategory('education', 'تعليم', Icons.school, Color(0xFF2B9AA8)),
  MoneyCategory('fun', 'ترفيه', Icons.celebration, Color(0xFFE0B23F)),
  MoneyCategory('clothes', 'لبس', Icons.checkroom, Color(0xFFB45AA0)),
  MoneyCategory(
    'charity',
    'صدقة وهدايا',
    Icons.volunteer_activism,
    Color(0xFF5FA34A),
  ),
  MoneyCategory('other', 'تانية', Icons.more_horiz, Color(0xFF7D8A86)),
];

const incomeCategories = [
  MoneyCategory('salary', 'مرتب', Icons.payments, Color(0xFF1F5E4A)),
  MoneyCategory('freelance', 'شغل حر', Icons.laptop_mac, Color(0xFF2E7D63)),
  MoneyCategory('gift', 'هدية', Icons.card_giftcard, Color(0xFFC9A54C)),
  MoneyCategory('other_income', 'تانية', Icons.more_horiz, Color(0xFF7D8A86)),
];

MoneyCategory categoryById(String id) => [
  ...expenseCategories,
  ...incomeCategories,
].firstWhere((c) => c.id == id, orElse: () => expenseCategories.last);

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    this.source = 'app',
    required this.createdAt,
  });

  final String id;
  final TxType type;

  /// بالجنيه
  final double amount;
  final String category;

  /// yyyy-MM-dd
  final String date;
  final String? note;
  final String source;
  final DateTime createdAt;

  String get month => date.substring(0, 7);

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'amount': amount,
    'category': category,
    'date': date,
    'month': month,
    'note': note,
    'source': source,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Transaction.fromMap(String id, Map<String, dynamic> m) {
    final created = m['createdAt'];
    return Transaction(
      id: id,
      type: m['type'] == 'income' ? TxType.income : TxType.expense,
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      category: (m['category'] as String?) ?? 'other',
      date: (m['date'] as String?) ?? '1970-01-01',
      note: m['note'] as String?,
      source: (m['source'] as String?) ?? 'app',
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : DateTime.now(),
    );
  }
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    this.saved = 0,
  });
  final String id;
  final String name;
  final double target;
  final double saved;

  double get progress =>
      target <= 0 ? 0 : (saved / target).clamp(0, 1).toDouble();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'target': target,
    'saved': saved,
  };

  factory SavingsGoal.fromMap(Map<String, dynamic> m) => SavingsGoal(
    id: m['id'] as String,
    name: (m['name'] as String?) ?? '',
    target: (m['target'] as num?)?.toDouble() ?? 0,
    saved: (m['saved'] as num?)?.toDouble() ?? 0,
  );
}

class MonthSummary {
  MonthSummary(this.transactions);
  final List<Transaction> transactions;

  double get spent => transactions
      .where((t) => t.type == TxType.expense)
      .fold(0, (s, t) => s + t.amount);
  double get income => transactions
      .where((t) => t.type == TxType.income)
      .fold(0, (s, t) => s + t.amount);

  /// المصروف لكل تصنيف من الأكبر للأصغر
  List<(MoneyCategory, double)> byCategory() {
    final m = <String, double>{};
    for (final t in transactions.where((t) => t.type == TxType.expense)) {
      m[t.category] = (m[t.category] ?? 0) + t.amount;
    }
    final list = m.entries.map((e) => (categoryById(e.key), e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }
}

String formatMoney(double v) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  final buf = StringBuffer();
  final digits = parts[0];
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${buf.toString()}${parts.length > 1 ? '.${parts[1]}' : ''} ج.م';
}
