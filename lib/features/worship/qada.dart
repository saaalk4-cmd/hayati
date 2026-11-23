import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/user_store.dart';
import 'prayer_service.dart';

/// قضاء الصلوات: users/{uid}/qada/state => {owed: {fajr: n...}, done: {fajr: n...}, dailyGoal: n}
class QadaState {
  const QadaState({
    this.owed = const {},
    this.done = const {},
    this.dailyGoal = 1,
  });

  /// عدد الصلوات الفايتة المتبقية لكل صلاة
  final Map<PrayerName, int> owed;

  /// اللي اتقضى لحد دلوقتي (للتحفيز)
  final Map<PrayerName, int> done;

  /// كام «يوم كامل» (5 صلوات) يتقضى في اليوم
  final int dailyGoal;

  int get totalOwed => owed.values.fold(0, (a, b) => a + b);
  int get totalDone => done.values.fold(0, (a, b) => a + b);

  /// أكتر صلاة فايتة بتحدد المدة
  int get daysToFinish {
    final maxOwed = owed.values.fold(0, (a, b) => a > b ? a : b);
    return dailyGoal <= 0 ? 0 : (maxOwed / dailyGoal).ceil();
  }

  double get progress {
    final all = totalOwed + totalDone;
    return all == 0 ? 0 : totalDone / all;
  }
}

Map<PrayerName, int> _counts(Object? m) => {
  for (final p in PrayerName.values)
    p: (((m as Map?) ?? const {})[p.name] as num?)?.toInt() ?? 0,
};

final qadaProvider = StreamProvider<QadaState>((ref) {
  return ref
      .watch(userStoreProvider)
      .watch('qada', 'state')
      .map(
        (d) => QadaState(
          owed: _counts(d?['owed']),
          done: _counts(d?['done']),
          dailyGoal: (d?['dailyGoal'] as num?)?.toInt() ?? 1,
        ),
      );
});

/// تقدير مبدئي: عدد سنين/أيام فايتة => نفس العدد لكل صلاة
Future<void> setQadaEstimate(WidgetRef ref, int days) =>
    ref.read(userStoreProvider).merge('qada', 'state', {
      'owed': {for (final p in PrayerName.values) p.name: days},
    });

Future<void> setQadaOwed(WidgetRef ref, PrayerName p, int value) =>
    ref.read(userStoreProvider).merge('qada', 'state', {
      'owed': {p.name: value < 0 ? 0 : value},
    });

/// سجّل إنك قضيت صلاة (أو يوم كامل لو [all] = true)
Future<void> logQada(WidgetRef ref, QadaState s, {PrayerName? prayer}) {
  final targets = prayer == null ? PrayerName.values : [prayer];
  return ref.read(userStoreProvider).merge('qada', 'state', {
    'owed': {
      for (final p in targets) p.name: ((s.owed[p] ?? 0) - 1).clamp(0, 1 << 30),
    },
    'done': {
      for (final p in targets)
        if ((s.owed[p] ?? 0) > 0) p.name: (s.done[p] ?? 0) + 1,
    },
  });
}

Future<void> setQadaGoal(WidgetRef ref, int goal) =>
    ref.read(userStoreProvider).merge('qada', 'state', {'dailyGoal': goal});
