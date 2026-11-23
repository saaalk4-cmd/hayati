import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/settings.dart';
import '../theme/palettes.dart';

/// اختيار الثيم: 3 كروت صغيرة كل واحد معاينة للألوان
class PalettePicker extends ConsumerWidget {
  const PalettePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(paletteProvider);
    return Row(
      children: [
        for (final p in allPalettes) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(paletteProvider.notifier).set(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: p.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: p.id == current.id ? p.accent : p.cardBorder,
                    width: p.id == current.id ? 2.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: p.hero,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(radius: 6, backgroundColor: p.accent),
                        const SizedBox(width: 4),
                        CircleAvatar(radius: 6, backgroundColor: p.primary),
                        const Spacer(),
                        if (p.id == current.id)
                          Icon(Icons.check_circle, size: 16, color: p.accent),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (p != allPalettes.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
