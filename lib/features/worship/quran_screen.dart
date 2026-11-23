import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import 'quran_progress.dart';
import '../../core/theme/palettes.dart';

class QuranScreen extends ConsumerWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quranProgressProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('وِردي من القرآن')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذّر التحميل')),
        data: (q) {
          final goalDone = q.todayPages >= q.dailyGoal;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: q.khatmaFraction,
                                strokeWidth: 12,
                                backgroundColor: context.palette.track,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(q.khatmaFraction * 100).toStringAsFixed(0)}%',
                                  style: text.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text('من الختمة', style: text.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        q.page == 0
                            ? 'لسه ما بدأتش الختمة دي'
                            : 'آخر صفحة: ${q.page} • الجزء ${juzOfPage(q.page)}',
                        style: text.titleMedium,
                      ),
                      if (q.khatmas > 0)
                        Text(
                          'ختمت ${q.khatmas} مرة، ما شاء الله 🌿',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.gold700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        goalDone
                            ? 'خلّصت وِرد النهارده ✓ (${q.todayPages} صفحة)'
                            : 'النهارده: ${q.todayPages} من ${q.dailyGoal} صفحات',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (q.todayPages / q.dailyGoal)
                            .clamp(0, 1)
                            .toDouble(),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 16),
                      const Text('قريت كام صفحة؟'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final n in [1, 2, 5, 10]) ...[
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () async {
                                  final finished = await addQuranPages(
                                    ref,
                                    q,
                                    n,
                                  );
                                  if (finished && context.mounted) {
                                    _celebrate(context);
                                  }
                                },
                                child: Text('+$n'),
                              ),
                            ),
                            if (n != 10) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('الوِرد اليومي'),
                      trailing: DropdownButton<int>(
                        value: q.dailyGoal,
                        underline: const SizedBox(),
                        items: [
                          for (final g in [1, 2, 4, 5, 10, 20])
                            DropdownMenuItem(
                              value: g,
                              child: Text(g == 20 ? 'جزء (20 ص)' : '$g صفحات'),
                            ),
                        ],
                        onChanged: (g) =>
                            g == null ? null : setQuranGoal(ref, g),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('حدد الصفحة اللي وصلتلها'),
                      onTap: () => _editPage(context, ref, q.page),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _celebrate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ختمت القرآن 🎉'),
        content: const Text('تقبّل الله منك. هنبدأ ختمة جديدة من أول صفحة.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('الحمد لله'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPage(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final controller = TextEditingController(
      text: current == 0 ? '' : '$current',
    );
    final page = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('رقم الصفحة (1 - 604)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(controller.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (page != null && page >= 0 && page <= quranPages) {
      await setQuranPage(ref, page);
    }
  }
}
