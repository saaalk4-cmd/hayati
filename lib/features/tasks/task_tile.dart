import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/date_utils.dart';
import '../../data/task.dart';
import '../../data/tasks_repository.dart';
import 'task_detail_sheet.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.dense = false});
  final HayatiTask task;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(tasksRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;
    final tile = ListTile(
      dense: dense,
      contentPadding: EdgeInsets.symmetric(horizontal: dense ? 0 : 16),
      leading: Checkbox(
        value: task.done,
        shape: const CircleBorder(),
        activeColor: scheme.primary,
        onChanged: (_) => repo.toggle(task),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.done ? TextDecoration.lineThrough : null,
          color: task.done ? scheme.onSurface.withValues(alpha: 0.5) : null,
        ),
      ),
      subtitle: dense ? null : _subtitle(context),
      onTap: () => showTaskDetail(context, task),
      trailing: task.source == 'assistant'
          ? Tooltip(
              message: 'أضافها المساعد',
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: scheme.secondary,
              ),
            )
          : null,
    );
    if (dense) return tile;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => repo.delete(task.id),
      child: tile,
    );
  }

  Widget? _subtitle(BuildContext context) {
    final parts = <String>[
      if (task.list != 'عام') task.list,
      if (task.dueDate != null) _dateLabel(task.dueDate!),
      if (task.remindAt != null)
        '⏰ ${task.remindAt!.hour.toString().padLeft(2, '0')}:${task.remindAt!.minute.toString().padLeft(2, '0')}',
      if (task.repeat != TaskRepeat.none) '🔁 ${task.repeat.ar}',
      if (task.subtasks.isNotEmpty)
        '☑ ${task.subtasksDone}/${task.subtasks.length}',
      if (task.priority == TaskPriority.high) '🚩 مهمة',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' • '),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  String _dateLabel(String key) {
    final now = DateTime.now();
    if (key == HayatiDates.dayKey(now)) return 'النهارده';
    if (key == HayatiDates.dayKey(now.add(const Duration(days: 1)))) {
      return 'بكرة';
    }
    if (key == HayatiDates.dayKey(now.subtract(const Duration(days: 1)))) {
      return 'امبارح';
    }
    return key;
  }
}
