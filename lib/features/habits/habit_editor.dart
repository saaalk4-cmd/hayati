import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notifications.dart';
import 'habit.dart';
import 'habits_repository.dart';

const _emojis = [
  '⭐',
  '📖',
  '🏃',
  '💧',
  '🕌',
  '🤲',
  '🥗',
  '😴',
  '🧘',
  '✍️',
  '📵',
  '💪',
];

Future<void> showHabitEditor(BuildContext context, {Habit? habit}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HabitEditor(habit: habit),
    );

class _HabitEditor extends ConsumerStatefulWidget {
  const _HabitEditor({this.habit});
  final Habit? habit;

  @override
  ConsumerState<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<_HabitEditor> {
  late final _title = TextEditingController(text: widget.habit?.title);
  late String _emoji = widget.habit?.emoji ?? '⭐';
  late Set<int> _days = {
    ...(widget.habit?.weekdays ?? const {1, 2, 3, 4, 5, 6, 7}),
  };
  late TimeOfDay? _reminder = _parse(widget.habit?.reminder);

  static TimeOfDay? _parse(String? r) {
    if (r == null) return null;
    final p = r.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _days.isEmpty) return;
    if (_reminder != null) await AppNotifications.instance.requestPermissions();
    final r = _reminder;
    await ref
        .read(habitsRepositoryProvider)
        .save(
          Habit(
            id: widget.habit?.id ?? '',
            title: title,
            emoji: _emoji,
            weekdays: _days,
            reminder: r == null
                ? null
                : '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}',
            createdAt: widget.habit?.createdAt ?? DateTime.now(),
          ),
        );
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
            Text(
              widget.habit == null ? 'عادة جديدة' : 'تعديل العادة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: widget.habit == null,
              decoration: const InputDecoration(
                hintText: 'مثلًا: أقرأ 10 صفحات',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _emojis)
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 20)),
                    selected: _emoji == e,
                    onSelected: (_) => setState(() => _emoji = e),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('الأيام'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final e in weekdayNamesAr.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: _days.contains(e.key),
                    onSelected: (v) => setState(() {
                      _days = {..._days};
                      v ? _days.add(e.key) : _days.remove(e.key);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.alarm, color: scheme.primary),
              title: Text(
                _reminder == null
                    ? 'من غير تذكير'
                    : 'تذكير الساعة ${_reminder!.format(context)}',
              ),
              trailing: _reminder == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _reminder = null),
                      icon: const Icon(Icons.close),
                    ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _reminder ?? const TimeOfDay(hour: 9, minute: 0),
                );
                if (t != null) setState(() => _reminder = t);
              },
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('حفظ')),
            if (widget.habit != null)
              TextButton(
                onPressed: () async {
                  await ref
                      .read(habitsRepositoryProvider)
                      .delete(widget.habit!.id);
                  if (context.mounted) Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                child: const Text('حذف العادة'),
              ),
          ],
        ),
      ),
    );
  }
}
