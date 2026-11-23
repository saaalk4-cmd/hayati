import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../data/task.dart';
import '../../data/tasks_repository.dart';

Future<void> showTaskDetail(BuildContext context, HayatiTask task) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TaskDetail(task: task),
    );

Color priorityColor(TaskPriority p) => switch (p) {
  TaskPriority.high => AppColors.danger,
  TaskPriority.normal => AppColors.gold500,
  TaskPriority.low => AppColors.emerald500,
};

class _TaskDetail extends ConsumerStatefulWidget {
  const _TaskDetail({required this.task});
  final HayatiTask task;

  @override
  ConsumerState<_TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends ConsumerState<_TaskDetail> {
  late HayatiTask _t = widget.task;
  late final _title = TextEditingController(text: widget.task.title);
  late final _notes = TextEditingController(text: widget.task.notes ?? '');
  final _sub = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _sub.dispose();
    super.dispose();
  }

  Future<void> _save(HayatiTask t) async {
    setState(() => _t = t);
    await ref.read(tasksRepositoryProvider).update(t);
  }

  void _addSub() {
    final v = _sub.text.trim();
    if (v.isEmpty) return;
    _sub.clear();
    _save(_t.copyWith(subtasks: [..._t.subtasks, Subtask(v)]));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
            TextField(
              controller: _title,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
              ),
              onSubmitted: (v) =>
                  v.trim().isEmpty ? null : _save(_t.copyWith(title: v.trim())),
            ),
            const SizedBox(height: 8),
            Text('الأولوية', style: text.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<TaskPriority>(
              showSelectedIcon: false,
              segments: [
                for (final p in TaskPriority.values.reversed)
                  ButtonSegment(
                    value: p,
                    label: Text(p.ar),
                    icon: Icon(Icons.flag, color: priorityColor(p), size: 18),
                  ),
              ],
              selected: {_t.priority},
              onSelectionChanged: (v) => _save(_t.copyWith(priority: v.first)),
            ),
            const SizedBox(height: 16),
            Text(
              _t.subtasks.isEmpty
                  ? 'خطوات'
                  : 'خطوات (${_t.subtasksDone}/${_t.subtasks.length})',
              style: text.labelLarge,
            ),
            for (var i = 0; i < _t.subtasks.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _t.subtasks[i].done,
                title: Text(
                  _t.subtasks[i].title,
                  style: TextStyle(
                    decoration: _t.subtasks[i].done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _save(
                    _t.copyWith(subtasks: [..._t.subtasks]..removeAt(i)),
                  ),
                ),
                onChanged: (_) => _save(
                  _t.copyWith(
                    subtasks: [
                      for (var j = 0; j < _t.subtasks.length; j++)
                        j == i ? _t.subtasks[j].toggled() : _t.subtasks[j],
                    ],
                  ),
                ),
              ),
            TextField(
              controller: _sub,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addSub(),
              decoration: InputDecoration(
                hintText: 'ضيف خطوة...',
                suffixIcon: IconButton(
                  onPressed: _addSub,
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'ملاحظات'),
              onChanged: (v) => _t = _t.copyWith(notes: v),
              onEditingComplete: () => _save(_t),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final title = _title.text.trim();
                      await _save(
                        _t.copyWith(
                          title: title.isEmpty ? _t.title : title,
                          notes: _notes.text.trim().isEmpty
                              ? null
                              : _notes.text.trim(),
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('حفظ'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'حذف',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () async {
                    await ref.read(tasksRepositoryProvider).delete(_t.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
