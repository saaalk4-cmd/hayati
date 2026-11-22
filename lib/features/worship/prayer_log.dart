import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../data/user_store.dart';
import 'prayer_service.dart';

/// حالة كل صلاة في اليوم — نفس القيم بيستخدمها المساعد على السيرفر
enum PrayerStatus { mosque, ontime, late, missed }

extension PrayerStatusAr on PrayerStatus {
  String get ar => const {
    PrayerStatus.mosque: 'في المسجد',
    PrayerStatus.ontime: 'في وقتها',
    PrayerStatus.late: 'متأخر',
    PrayerStatus.missed: 'فاتتني',
  }[this]!;
}

/// سجل الصلوات: users/{uid}/prayers/{yyyy-MM-dd} => {fajr: 'ontime', ...}
final prayerLogProvider =
    StreamProvider.family<Map<PrayerName, PrayerStatus>, String>((ref, day) {
      return ref.watch(userStoreProvider).watch('prayers', day).map((data) {
        final result = <PrayerName, PrayerStatus>{};
        if (data == null) return result;
        for (final p in PrayerName.values) {
          final v = data[p.name];
          final status = PrayerStatus.values.where((s) => s.name == v);
          if (status.isNotEmpty) result[p] = status.first;
        }
        return result;
      });
    });

final todayPrayerLogProvider = Provider<Map<PrayerName, PrayerStatus>>((ref) {
  final day = HayatiDates.dayKey(DateTime.now());
  return ref.watch(prayerLogProvider(day)).value ?? const {};
});

Future<void> logPrayer(
  WidgetRef ref,
  String day,
  PrayerName p,
  PrayerStatus? status,
) {
  return ref.read(userStoreProvider).merge('prayers', day, {
    p.name: status?.name,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  });
}
