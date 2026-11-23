import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notifications.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/task.dart';
import '../../data/tasks_repository.dart';

Future<void> showAddTaskSheet(BuildContext context, {String? list}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddTaskSheet(initialList: list),
    );

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet({this.initialList});
  final String? initialList;

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _title = TextEditingController();
  late String _list = widget.initialList ?? 'عام';
  DateTime? _due = DateTime.now();
  TaskRepeat _repeat = TaskRepeat.none;
  TimeOfDay? _remind;
  TaskPriority _priority = TaskPriority.normal;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _title.text.trim();
    if (t.isEmpty) return;
    DateTime? remindAt;
    if (_remind != null) {
      final d = _due ?? DateTime.now();
      remindAt = DateTime(
        d.year,
        d.month,
        d.day,
        _remind!.hour,
        _remind!.minute,
      );
      await AppNotifications.instance.requestPermissions();
    }
    await ref
        .read(tasksRepositoryProvider)
        .addTask(
          HayatiTask(
            id: '',
            title: t,
            list: _list,
            dueDate: _due == null ? null : HayatiDates.dayKey(_due!),
            repeat: _repeat,
            remindAt: remindAt,
            createdAt: DateTime.now(),
            priority: _priority,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  String _dueLabel() {
    final d = _due;
    if (d == null) return 'من غير معاد';
    final today = DateTime.now();
    final key = HayatiDates.dayKey(d);
    if (key == HayatiDates.dayKey(today)) return 'النهارده';
    if (key == HayatiDates.dayKey(today.add(const Duration(days: 1)))) {
      return 'بكرة';
    }
    return arFormat('EEEE d MMMM', d);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
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
            Text('مهمة جديدة', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(hintText: 'عايز تعمل إيه؟'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final l in taskLists)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(l),
                        selected: _list == l,
                        onSelected: (_) => setState(() => _list = l),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('النهارده'),
                  selected:
                      _due != null &&
                      HayatiDates.dayKey(_due!) == HayatiDates.dayKey(now),
                  onSelected: (_) => setState(() => _due = now),
                ),
                ChoiceChip(
                  label: const Text('بكرة'),
                  selected:
                      _due != null &&
                      HayatiDates.dayKey(_due!) ==
                          HayatiDates.dayKey(now.add(const Duration(days: 1))),
                  onSelected: (_) =>
                      setState(() => _due = now.add(const Duration(days: 1))),
                ),
                ChoiceChip(
                  label: const Text('من غير معاد'),
                  selected: _due == null,
                  onSelected: (_) => setState(() {
                    _due = null;
                    _remind = null;
                    _repeat = TaskRepeat.none;
                  }),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(_dueLabel()),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 5),
                  initialDate: _due ?? now,
                );
                if (d != null) setState(() => _due = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: Text(_repeat.ar),
              enabled: _due != null,
              trailing: PopupMenuButton<TaskRepeat>(
                enabled: _due != null,
                icon: const Icon(Icons.expand_more),
                onSelected: (r) => setState(() => _repeat = r),
                itemBuilder: (_) => [
                  for (final r in TaskRepeat.values)
                    PopupMenuItem(value: r, child: Text(r.ar)),
                ],
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm),
              title: Text(
                _remind == null
                    ? 'من غير تذكير'
                    : 'تذكير الساعة ${_remind!.format(context)}',
              ),
              trailing: _remind == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _remind = null),
                      icon: const Icon(Icons.close),
                    ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _remind ?? TimeOfDay.now(),
                );
                if (t != null) {
                  setState(() {
                    _remind = t;
                    _due ??= now;
                  });
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.flag, color: AppColors.danger),
              title: const Text('مهمة مهمة (أولوية عالية)'),
              value: _priority == TaskPriority.high,
              onChanged: (v) => setState(
                () => _priority = v ? TaskPriority.high : TaskPriority.normal,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('إضافة')),
          ],
        ),
      ),
    );
  }
}
