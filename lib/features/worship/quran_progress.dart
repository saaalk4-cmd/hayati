import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../data/user_store.dart';

/// بداية كل جزء في مصحف المدينة (604 صفحة)
const juzStartPages = [
  1, 22, 42, 62, 82, 102, 121, 142, 162, 182, //
  201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
  402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
];
const quranPages = 604;

int juzOfPage(int page) {
  for (var i = juzStartPages.length - 1; i >= 0; i--) {
    if (page >= juzStartPages[i]) return i + 1;
  }
  return 1;
}

class QuranProgress {
  const QuranProgress({
    this.page = 0,
    this.khatmas = 0,
    this.dailyGoal = 4,
    this.todayPages = 0,
  });

  /// آخر صفحة اتقرت (0 = لسه ما بدأش)
  final int page;
  final int khatmas;
  final int dailyGoal;
  final int todayPages;

  double get khatmaFraction => page / quranPages;
}

/// users/{uid}/quran/progress
final quranProgressProvider = StreamProvider<QuranProgress>((ref) {
  final today = HayatiDates.dayKey(DateTime.now());
  return ref.watch(userStoreProvider).watch('quran', 'progress').map((d) {
    if (d == null) return const QuranProgress();
    final log = (d['log'] as Map?)?.cast<String, dynamic>() ?? const {};
    return QuranProgress(
      page: (d['page'] as num?)?.toInt() ?? 0,
      khatmas: (d['khatmas'] as num?)?.toInt() ?? 0,
      dailyGoal: (d['dailyGoal'] as num?)?.toInt() ?? 4,
      todayPages: (log[today] as num?)?.toInt() ?? 0,
    );
  });
});

/// يضيف صفحات اتقرت النهارده؛ ولو الختمة خلصت يبدأ ختمة جديدة
Future<bool> addQuranPages(WidgetRef ref, QuranProgress p, int pages) async {
  final today = HayatiDates.dayKey(DateTime.now());
  var page = p.page + pages;
  var khatmas = p.khatmas;
  var finished = false;
  if (page >= quranPages) {
    page = 0;
    khatmas++;
    finished = true;
  }
  await ref.read(userStoreProvider).merge('quran', 'progress', {
    'page': page,
    'khatmas': khatmas,
    'log': {today: p.todayPages + pages},
  });
  return finished;
}

Future<void> setQuranGoal(WidgetRef ref, int goal) =>
    ref.read(userStoreProvider).merge('quran', 'progress', {'dailyGoal': goal});

Future<void> setQuranPage(WidgetRef ref, int page) => ref
    .read(userStoreProvider)
    .merge('quran', 'progress', {'page': page.clamp(0, quranPages - 1)});
