import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:convert';
import 'dart:typed_data';

import '../../core/theme/app_colors.dart';
import 'add_transaction_sheet.dart';
import 'money_models.dart';
import 'money_repository.dart';
import '../../core/utils/date_utils.dart';

String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final key = monthKey(_month);
    final txs = ref.watch(monthTransactionsProvider(key));
    final settings =
        ref.watch(moneySettingsProvider).value ?? const MoneySettings();
    final isCurrent = key == monthKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('فلوسي'),
        actions: [
          IconButton(
            tooltip: 'تصدير الشهر (CSV)',
            onPressed: () => _exportCsv(
              ref.read(monthTransactionsProvider(key)).value ?? const [],
              key,
            ),
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'الميزانية',
            onPressed: () => _editBudget(context, settings.monthlyBudget),
            icon: const Icon(Icons.savings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTransactionSheet(context),
        child: const Icon(Icons.add),
      ),
      body: txs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذّر التحميل')),
        data: (list) {
          final s = MonthSummary(list);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  Text(
                    arFormat('MMMM y', _month),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: isCurrent
                        ? null
                        : () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + 1,
                            ),
                          ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ],
              ),
              _SummaryCard(
                summary: s,
                budget: settings.monthlyBudget,
                previousSpent: MonthSummary(
                  ref
                          .watch(
                            monthTransactionsProvider(
                              monthKey(DateTime(_month.year, _month.month - 1)),
                            ),
                          )
                          .value ??
                      const [],
                ).spent,
              ),
              const SizedBox(height: 12),
              if (s.byCategory().isNotEmpty) ...[
                _CategoryBreakdown(summary: s),
                const SizedBox(height: 12),
              ],
              _RecurringCard(settings: settings),
              const SizedBox(height: 12),
              _GoalsCard(goals: settings.goals),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'مفيش حركات الشهر ده.\nدوس + أو قول للمساعد: «صرفت 150 جنيه أكل»',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._dayGroups(context, list),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _dayGroups(BuildContext context, List<Transaction> list) {
    final out = <Widget>[];
    String? current;
    for (final t in list) {
      if (t.date != current) {
        current = t.date;
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              arFormat('EEEE d MMMM', DateTime.parse(t.date)),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      out.add(_TxTile(tx: t));
    }
    return out;
  }

  Future<void> _exportCsv(List<Transaction> list, String month) async {
    final csv = transactionsToCsv(list);
    // BOM عشان Excel يقرا العربي صح
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv')],
        fileNameOverrides: ['hayati-$month.csv'],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, double? current) async {
    final c = TextEditingController(
      text: current == null ? '' : current.toStringAsFixed(0),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('ميزانية الشهر'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'ج.م',
            hintText: 'مثلًا 8000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, 'clear'),
            child: const Text('من غير ميزانية'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    c.dispose();
    if (result == null) return;
    await setMonthlyBudget(
      ref,
      result == 'clear' ? null : double.tryParse(result),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.budget,
    required this.previousSpent,
  });
  final MonthSummary summary;
  final double? budget;
  final double previousSpent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = budget;
    final ratio = b == null || b <= 0 ? null : summary.spent / b;
    final over = ratio != null && ratio > 1;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emerald700, AppColors.emerald900],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'صرفت الشهر ده',
            style: text.bodyMedium?.copyWith(color: Colors.white70),
          ),
          Text(
            formatMoney(summary.spent),
            style: text.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (ratio != null) ...[
            LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.white24,
              color: over ? const Color(0xFFFF8A80) : AppColors.gold500,
            ),
            const SizedBox(height: 8),
            Text(
              over
                  ? 'عدّيت الميزانية بـ ${formatMoney(summary.spent - b!)}'
                  : 'باقي ${formatMoney(b! - summary.spent)} من ميزانية ${formatMoney(b)}',
              style: text.bodyMedium?.copyWith(
                color: over ? const Color(0xFFFFCDD2) : AppColors.gold200,
              ),
            ),
          ] else
            Text(
              'حدد ميزانية للشهر من أيقونة 🐷 فوق',
              style: text.bodySmall?.copyWith(color: Colors.white70),
            ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            children: [
              const Icon(
                Icons.arrow_downward,
                color: AppColors.gold500,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'الدخل: ${formatMoney(summary.income)}',
                style: text.bodyMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
          if (previousSpent > 0) ...[
            const SizedBox(height: 6),
            Text(
              _compare(summary.spent, previousSpent),
              style: text.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  String _compare(double now, double prev) {
    final pct = ((now - prev) / prev * 100).round();
    if (pct == 0) return 'زي الشهر اللي فات بالظبط';
    return pct > 0
        ? '⬆ أكتر من الشهر اللي فات بـ $pct%'
        : '⬇ أقل من الشهر اللي فات بـ ${-pct}% 👏';
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final cats = summary.byCategory();
    final total = summary.spent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'صرفت على إيه',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  for (final (c, v) in cats)
                    Expanded(
                      flex: (v / total * 1000).round().clamp(1, 1000),
                      child: Container(height: 12, color: c.color),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final (c, v) in cats.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(c.icon, size: 18, color: c.color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.name)),
                    Text(
                      '${(v / total * 100).round()}%  ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      formatMoney(v),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalsCard extends ConsumerWidget {
  const _GoalsCard({required this.goals});
  final List<SavingsGoal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'أهداف الادخار',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _newGoal(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('هدف جديد'),
                ),
              ],
            ),
            if (goals.isEmpty)
              const Text('مثلًا: عمرة، موبايل جديد، صندوق طوارئ 🎯'),
            for (final g in goals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(g.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: g.progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.gold500,
                    ),
                    const SizedBox(height: 4),
                    Text('${formatMoney(g.saved)} من ${formatMoney(g.target)}'),
                  ],
                ),
                trailing: IconButton(
                  tooltip: 'حوّش',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _deposit(context, ref, g),
                ),
                onLongPress: () =>
                    saveGoals(ref, goals.where((x) => x.id != g.id).toList()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _newGoal(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final target = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('هدف ادخار جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'الهدف'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                suffixText: 'ج.م',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final t = double.tryParse(target.text);
    if (ok == true && name.text.trim().isNotEmpty && t != null && t > 0) {
      await saveGoals(ref, [
        ...goals,
        SavingsGoal(id: const Uuid().v4(), name: name.text.trim(), target: t),
      ]);
    }
    name.dispose();
    target.dispose();
  }

  Future<void> _deposit(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal g,
  ) async {
    final c = TextEditingController();
    final v = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('حوّش لـ ${g.name}'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'ج.م'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(d, double.tryParse(c.text)),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v == null || v <= 0) return;
    await saveGoals(ref, [
      for (final x in goals)
        x.id == g.id
            ? SavingsGoal(
                id: x.id,
                name: x.name,
                target: x.target,
                saved: x.saved + v,
              )
            : x,
    ]);
  }
}

class _TxTile extends ConsumerWidget {
  const _TxTile({required this.tx});
  final Transaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = categoryById(tx.category);
    final income = tx.type == TxType.income;
    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(transactionsRepositoryProvider).delete(tx.id),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: c.color.withValues(alpha: 0.15),
            child: Icon(c.icon, color: c.color),
          ),
          title: Text(tx.note ?? c.name),
          subtitle: tx.note == null ? null : Text(c.name),
          trailing: Text(
            '${income ? '+' : '-'}${formatMoney(tx.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: income ? AppColors.emerald500 : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// تحويل حركات الشهر لـ CSV (التاريخ، النوع، التصنيف، المبلغ، الملاحظة)
String transactionsToCsv(List<Transaction> list) {
  String esc(String v) =>
      v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  final rows = <String>['التاريخ,النوع,التصنيف,المبلغ,ملاحظة'];
  for (final t in list) {
    rows.add(
      [
        t.date,
        t.type == TxType.expense ? 'مصروف' : 'دخل',
        categoryById(t.category).name,
        t.amount.toStringAsFixed(2),
        esc(t.note ?? ''),
      ].join(','),
    );
  }
  return rows.join('\n');
}

/// المصروفات الثابتة الشهرية
class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.settings});
  final MoneySettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = settings.recurring;
    final total = list.fold<double>(0, (s, r) => s + r.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'مصروفات ثابتة كل شهر',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _add(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            if (list.isEmpty)
              const Text(
                'إيجار، فواتير، اشتراكات... بتتسجل لوحدها في معادها 🔁',
              )
            else ...[
              for (final r in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    categoryById(r.category).icon,
                    color: categoryById(r.category).color,
                  ),
                  title: Text(r.title),
                  subtitle: Text('يوم ${r.dayOfMonth} من كل شهر'),
                  trailing: Text(
                    formatMoney(r.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onLongPress: () => saveRecurring(
                    ref,
                    list.where((x) => x.id != r.id).toList(),
                  ),
                ),
              Text(
                'المجموع: ${formatMoney(total)} في الشهر',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    var category = 'bills';
    var day = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: const Text('مصروف ثابت جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'الاسم (إيجار، نت...)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    suffixText: 'ج.م',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: [
                    for (final c in expenseCategories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => category = v ?? 'bills',
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration: const InputDecoration(
                    labelText: 'يوم كام في الشهر',
                  ),
                  items: [
                    for (var i = 1; i <= 28; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (v) => day = v ?? 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    final a = double.tryParse(amount.text);
    if (ok == true && title.text.trim().isNotEmpty && a != null && a > 0) {
      await saveRecurring(ref, [
        ...settings.recurring,
        RecurringExpense(
          id: const Uuid().v4(),
          title: title.text.trim(),
          amount: a,
          category: category,
          dayOfMonth: day,
        ),
      ]);
    }
    title.dispose();
    amount.dispose();
  }
}
