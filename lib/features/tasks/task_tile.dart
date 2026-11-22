import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/task.dart';
import '../../data/tasks_repository.dart';

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
      trailing: task.source == 'assistant'
          ? Tooltip(
              message: 'أضافها المساعد',
              child: Icon(Icons.auto_awesome, size: 16, color: scheme.secondary),
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
}
