import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/date_utils.dart';
import 'money_models.dart';
import 'money_repository.dart';

Future<void> showAddTransactionSheet(
  BuildContext context, {
  TxType type = TxType.expense,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _AddTransactionSheet(initialType: type),
);

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet({required this.initialType});
  final TxType initialType;

  @override
  ConsumerState<_AddTransactionSheet> createState() => _State();
}

class _State extends ConsumerState<_AddTransactionSheet> {
  late TxType _type = widget.initialType;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _category;
  DateTime _date = DateTime.now();

  List<MoneyCategory> get _cats =>
      _type == TxType.expense ? expenseCategories : incomeCategories;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    await ref
        .read(transactionsRepositoryProvider)
        .add(
          Transaction(
            id: '',
            type: _type,
            amount: amount,
            category: _category ?? _cats.last.id,
            date: HayatiDates.dayKey(_date),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
    HapticFeedback.lightImpact();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(
                  value: TxType.expense,
                  label: Text('مصروف'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TxType.income,
                  label: Text('دخل'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _category = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: 'ج.م',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _cats)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18, color: c.color),
                    label: Text(c.name),
                    selected: _category == c.id,
                    onSelected: (_) => setState(() => _category = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(hintText: 'ملاحظة (اختياري)'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event, color: scheme.primary),
              title: Text(
                HayatiDates.dayKey(_date) == HayatiDates.dayKey(DateTime.now())
                    ? 'النهارده'
                    : arFormat('EEEE d MMMM', _date),
              ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(now.year - 2),
                  lastDate: now,
                  initialDate: _date,
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            FilledButton(onPressed: _save, child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}
