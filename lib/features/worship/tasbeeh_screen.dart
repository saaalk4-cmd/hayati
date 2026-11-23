import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/user_store.dart';
import '../../core/theme/palettes.dart';

const tasbeehPhrases = [
  'سُبْحَانَ اللَّهِ',
  'الْحَمْدُ لِلَّهِ',
  'اللَّهُ أَكْبَرُ',
  'لَا إِلَهَ إِلَّا اللَّهُ',
  'أَسْتَغْفِرُ اللَّهَ',
  'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
];

/// مجموع تسبيح النهارده: users/{uid}/tasbeeh/{yyyy-MM-dd} => {total: n}
final tasbeehTodayProvider = StreamProvider<int>((ref) {
  final day = HayatiDates.dayKey(DateTime.now());
  return ref
      .watch(userStoreProvider)
      .watch('tasbeeh', day)
      .map((d) => (d?['total'] as num?)?.toInt() ?? 0);
});

class TasbeehScreen extends ConsumerStatefulWidget {
  const TasbeehScreen({super.key});

  @override
  ConsumerState<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends ConsumerState<TasbeehScreen> {
  int _phrase = 0;
  int _count = 0;
  int _target = 33;
  int _pending = 0;

  void _tap() {
    HapticFeedback.selectionClick();
    setState(() {
      _count++;
      _pending++;
    });
    if (_count == _target) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('أتممت $_target ✓ تقبّل الله')));
    }
    // بنحفظ كل 10 تسبيحات عشان منكترش الكتابة
    if (_pending >= 10) _flush();
  }

  Future<void> _flush() async {
    if (_pending == 0) return;
    final n = _pending;
    _pending = 0;
    final store = ref.read(userStoreProvider);
    final day = HayatiDates.dayKey(DateTime.now());
    final cur = await store.get('tasbeeh', day);
    await store.merge('tasbeeh', day, {
      'total': ((cur?['total'] as num?)?.toInt() ?? 0) + n,
    });
  }

  @override
  void deactivate() {
    _flush();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(tasbeehTodayProvider).value ?? 0;
    final text = Theme.of(context).textTheme;
    final progress = (_count % _target) / _target;
    return Scaffold(
      appBar: AppBar(
        title: const Text('السبحة'),
        actions: [
          IconButton(
            tooltip: 'من الأول',
            onPressed: () => setState(() => _count = 0),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < tasbeehPhrases.length; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(tasbeehPhrases[i]),
                      selected: _phrase == i,
                      onSelected: (_) => setState(() {
                        _phrase = i;
                        _count = 0;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 33, label: Text('33')),
              ButtonSegment(value: 100, label: Text('100')),
              ButtonSegment(value: 1000, label: Text('1000')),
            ],
            selected: {_target},
            onSelectionChanged: (v) => setState(() {
              _target = v.first;
              _count = 0;
            }),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _tap,
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _count >= _target && _count % _target == 0
                              ? 1
                              : progress,
                          strokeWidth: 10,
                          backgroundColor: context.palette.track,
                          color: AppColors.gold500,
                        ),
                      ),
                      Container(
                        width: 220,
                        height: 220,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.emerald700,
                              AppColors.emerald900,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_count',
                              style: text.displayMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              tasbeehPhrases[_phrase],
                              style: text.titleMedium?.copyWith(
                                color: AppColors.gold500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Text(
              'مجموع تسبيحك النهارده: ${today + _pending}',
              style: text.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
