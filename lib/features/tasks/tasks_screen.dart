import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/date_utils.dart';
import '../../data/task.dart';
import '../../data/tasks_repository.dart';
import 'add_task_sheet.dart';
import 'task_tile.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String? _list;
  bool _showDone = false;
  bool _searching = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'دوّر في مهامك...',
                  filled: false,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              )
            : const Text('مهامي'),
        actions: [
          IconButton(
            tooltip: _searching ? 'إلغاء البحث' : 'بحث',
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
          IconButton(
            tooltip: _showDone ? 'إخفاء اللي خلص' : 'إظهار اللي خلص',
            onPressed: () => setState(() => _showDone = !_showDone),
            icon: Icon(
              _showDone ? Icons.visibility_off_outlined : Icons.done_all,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTaskSheet(context, list: _list),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: const Text('الكل'),
                    selected: _list == null,
                    onSelected: (_) => setState(() => _list = null),
                  ),
                ),
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
          Expanded(
            child: tasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('تعذّر تحميل المهام')),
              data: (all) {
                final list = all
                    .where((t) => _list == null || t.list == _list)
                    .where(
                      (t) =>
                          _query.isEmpty ||
                          t.title.contains(_query) ||
                          (t.notes?.contains(_query) ?? false) ||
                          t.subtasks.any((s) => s.title.contains(_query)),
                    )
                    .toList();
                final groups = _group(list);
                if (groups.every((g) => g.$2.isEmpty)) return const _Empty();
                return ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final (title, items) in groups)
                      if (items.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                          child: Text(
                            '$title (${items.length})',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        for (final t in items) TaskTile(task: t),
                      ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<(String, List<HayatiTask>)> _group(List<HayatiTask> list) {
    final today = HayatiDates.dayKey(DateTime.now());
    final overdue = <HayatiTask>[], todayL = <HayatiTask>[];
    final later = <HayatiTask>[],
        someday = <HayatiTask>[],
        done = <HayatiTask>[];
    for (final t in list) {
      if (t.done) {
        done.add(t);
      } else if (t.dueDate == null) {
        someday.add(t);
      } else if (t.dueDate!.compareTo(today) < 0) {
        overdue.add(t);
      } else if (t.dueDate == today) {
        todayL.add(t);
      } else {
        later.add(t);
      }
    }
    return [
      ('متأخرة', overdue),
      ('النهارده', todayL),
      ('الجاية', later),
      ('في أي وقت', someday),
      if (_showDone) ('خلصت', done),
    ];
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'مفيش مهام هنا.\nدوس + أو اطلب من المساعد يرتبلك يومك.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
