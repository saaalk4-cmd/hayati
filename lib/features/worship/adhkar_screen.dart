import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import 'adhkar_data.dart';

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late final AdhkarGroup group =
      allAdhkar.firstWhere((g) => g.id == widget.groupId);
  late final List<int> _remaining = [for (final d in group.items) d.count];

  void _tap(int i) {
    if (_remaining[i] == 0) return;
    HapticFeedback.lightImpact();
    setState(() => _remaining[i]--);
    if (_remaining.every((r) => r == 0)) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تقبّل الله منك 🌿')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _remaining.where((r) => r == 0).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
        actions: [
          IconButton(
            tooltip: 'من الأول',
            onPressed: () => setState(() {
              for (var i = 0; i < group.items.length; i++) {
                _remaining[i] = group.items[i].count;
              }
            }),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: done / group.items.length),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: group.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final d = group.items[i];
          final left = _remaining[i];
          final finished = left == 0;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: finished ? 0.55 : 1,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _tap(i),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(d.text,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(height: 2)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.note == null ? d.source : '${d.source} • ${d.note}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: finished
                                  ? AppColors.emerald500
                                  : AppColors.gold500,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: finished
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : Text('$left',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.emerald900)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
