import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/notifications.dart';
import '../../core/theme/app_colors.dart';
import 'family_models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/palettes.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مناسباتي وأهلي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'المناسبات'),
              Tab(text: 'صلة الرحم'),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            onPressed: () {
              final tab = DefaultTabController.of(context).index;
              tab == 0 ? _addOccasion(context, ref) : _addPerson(context, ref);
            },
            child: const Icon(Icons.add),
          ),
        ),
        body: const TabBarView(children: [_OccasionsTab(), _PeopleTab()]),
      ),
    );
  }
}

class _OccasionsTab extends ConsumerWidget {
  const _OccasionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(occasionsProvider).value ?? const [];
    final now = DateTime.now();
    if (list.isEmpty) {
      return const _Empty(
        emoji: '🎂',
        text: 'ضيف أعياد ميلاد أهلك وصحابك ومناسباتك المهمة،\nوهفكّرك قبلها.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final o = list[i];
        final days = o.daysUntil(now);
        final years = o.yearsAtNext(now);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: Text(o.type.emoji, style: const TextStyle(fontSize: 30)),
            title: Text(
              o.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                arFormat('d MMMM', o.nextDate(now)),
                if (years != null && years > 0)
                  o.type == OccasionType.birthday
                      ? 'هيكمّل $years سنة'
                      : '$years سنة',
              ].join(' • '),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: days <= 3 ? AppColors.gold500 : context.palette.track,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                days == 0
                    ? 'النهارده 🎉'
                    : days == 1
                    ? 'بكرة'
                    : 'بعد $days يوم',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald900,
                ),
              ),
            ),
            onLongPress: () => _confirmDelete(context, () async {
              await saveOccasions(
                ref,
                list.where((x) => x.id != o.id).toList(),
              );
            }),
          ),
        );
      },
    );
  }
}

class _PeopleTab extends ConsumerWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(peopleProvider).value ?? const [];
    final now = DateTime.now();
    if (list.isEmpty) {
      return const _Empty(
        emoji: '💚',
        text: 'ضيف الناس اللي عايز تفضل على تواصل معاهم،\nوهفكّرك لو بقالك كتير ما كلمتهمش.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final p = list[i];
        final since = p.daysSince(now);
        final due = p.isDue(now);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: due ? context.palette.accent.withValues(alpha: 0.16) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: context.palette.accent.withValues(alpha: 0.2),
              child: Text(
                p.name.isEmpty ? '?' : p.name.characters.first,
                style: const TextStyle(
                  color: AppColors.emerald900,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              p.relation.isEmpty ? p.name : '${p.name} (${p.relation})',
            ),
            subtitle: Text(
              p.lastContact == null
                  ? 'لسه ما سجّلتش آخر مرة كلمته'
                  : since == 0
                  ? 'كلمته النهارده ✓'
                  : 'آخر مرة من $since يوم${due ? ' • وحشك 💚' : ''}',
            ),
            trailing: FilledButton.tonal(
              onPressed: () => savePeople(ref, [
                for (final x in list) x.id == p.id ? x.contactedNow() : x,
              ]),
              child: const Text('كلمته'),
            ),
            onLongPress: () => _confirmDelete(context, () async {
              await savePeople(ref, list.where((x) => x.id != p.id).toList());
            }),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  Future<void> Function() onDelete,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('حذف؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('لا'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('احذف'),
        ),
      ],
    ),
  );
  if (ok == true) await onDelete();
}

Future<void> _addOccasion(BuildContext context, WidgetRef ref) async {
  final title = TextEditingController();
  final year = TextEditingController();
  var type = OccasionType.birthday;
  DateTime? date;
  var remind = 1;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('مناسبة جديدة', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<OccasionType>(
              showSelectedIcon: false,
              segments: [
                for (final t in OccasionType.values)
                  ButtonSegment(value: t, label: Text('${t.emoji} ${t.ar}')),
              ],
              selected: {type},
              onSelectionChanged: (s) => setState(() => type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: InputDecoration(
                hintText: type == OccasionType.birthday
                    ? 'عيد ميلاد ماما'
                    : 'عيد جوازنا',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                date == null ? 'اختار التاريخ' : arFormat('d MMMM', date!),
              ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: c,
                  firstDate: DateTime(1920),
                  lastDate: DateTime(now.year + 2),
                  initialDate: date ?? now,
                );
                if (d != null) {
                  setState(() {
                    date = d;
                    if (d.year < now.year) year.text = '${d.year}';
                  });
                }
              },
            ),
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'سنة البداية (اختياري) لحساب العمر',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: remind,
              decoration: const InputDecoration(labelText: 'فكّرني'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('في نفس اليوم')),
                DropdownMenuItem(value: 1, child: Text('قبلها بيوم')),
                DropdownMenuItem(value: 3, child: Text('قبلها بـ 3 أيام')),
                DropdownMenuItem(value: 7, child: Text('قبلها بأسبوع')),
              ],
              onChanged: (v) => remind = v ?? 1,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    ),
  );
  final d = date;
  if (saved == true && title.text.trim().isNotEmpty && d != null) {
    await AppNotifications.instance.requestPermissions();
    final current = ref.read(occasionsProvider).value ?? const [];
    await saveOccasions(ref, [
      ...current,
      Occasion(
        id: const Uuid().v4(),
        title: title.text.trim(),
        type: type,
        month: d.month,
        day: d.day,
        year: int.tryParse(year.text),
        remindDaysBefore: remind,
      ),
    ]);
  }
  title.dispose();
  year.dispose();
}

Future<void> _addPerson(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final relation = TextEditingController();
  var every = 14;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(c).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('شخص جديد', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(hintText: 'الاسم'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: relation,
            decoration: const InputDecoration(
              hintText: 'القرابة (خالتي، جدو...)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: every,
            decoration: const InputDecoration(labelText: 'عايز أكلمه كل'),
            items: const [
              DropdownMenuItem(value: 3, child: Text('3 أيام')),
              DropdownMenuItem(value: 7, child: Text('أسبوع')),
              DropdownMenuItem(value: 14, child: Text('أسبوعين')),
              DropdownMenuItem(value: 30, child: Text('شهر')),
            ],
            onChanged: (v) => every = v ?? 14,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  if (saved == true && name.text.trim().isNotEmpty) {
    final current = ref.read(peopleProvider).value ?? const [];
    await savePeople(ref, [
      ...current,
      Person(
        id: const Uuid().v4(),
        name: name.text.trim(),
        relation: relation.text.trim(),
        everyDays: every,
      ),
    ]);
  }
  name.dispose();
  relation.dispose();
}
