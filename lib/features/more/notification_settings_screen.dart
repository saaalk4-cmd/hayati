import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notifications.dart';
import '../reminders/smart_reminders.dart';
import '../worship/prayer_settings.dart';

/// كل الإشعارات في مكان واحد: تفعّل وتقفل كل نوع لوحده
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(reminderSettingsProvider);
    final prayer = ref.watch(prayerSettingsProvider);
    final r = ref.read(reminderSettingsProvider.notifier);
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          section('الصلاة'),
          SwitchListTile(
            secondary: const Icon(Icons.mosque_outlined),
            title: const Text('الأذان'),
            subtitle: const Text('إشعار بدخول وقت كل صلاة، وفيه زرار «صليت»'),
            value: prayer.adhanNotifications,
            onChanged: (v) async {
              if (v) await AppNotifications.instance.requestPermissions();
              await ref.read(prayerSettingsProvider.notifier).setAdhan(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('تنبيه قبل الصلاة'),
            subtitle: const Text('عشان تلحق تتوضّى وتستعد'),
            trailing: DropdownButton<int>(
              value: reminders.prePrayerMinutes,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('مقفول')),
                DropdownMenuItem(value: 5, child: Text('5 دقايق')),
                DropdownMenuItem(value: 10, child: Text('10 دقايق')),
                DropdownMenuItem(value: 15, child: Text('15 دقيقة')),
              ],
              onChanged: (v) => r.update(prePrayer: v),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_stories_outlined),
            title: const Text('أذكار الصباح والمساء'),
            subtitle: const Text('بعد الفجر وبعد العصر بنص ساعة'),
            value: reminders.adhkar,
            onChanged: (v) => r.update(adhkar: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.menu_book_outlined),
            title: const Text('سورة الكهف'),
            subtitle: const Text('كل جمعة الساعة 10 الصبح'),
            value: reminders.kahf,
            onChanged: (v) => r.update(kahf: v),
          ),
          section('يومك'),
          SwitchListTile(
            secondary: const Icon(Icons.nights_stay),
            title: const Text('ملخص الليل'),
            subtitle: const Text(
              'الساعة 9:30: خلّصت إيه وصليت كام وصرفت قد إيه',
            ),
            value: reminders.nightSummary,
            onChanged: (v) => r.update(night: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_twilight),
            title: const Text('ملخص الصبح'),
            subtitle: Text('كل يوم الساعة ${reminders.morningHour} الصبح'),
            value: reminders.morningSummary,
            onChanged: (v) async {
              if (v) await AppNotifications.instance.requestPermissions();
              await ref
                  .read(reminderSettingsProvider.notifier)
                  .update(morning: v);
            },
          ),
          if (reminders.morningSummary)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('الساعة'),
              trailing: DropdownButton<int>(
                value: reminders.morningHour,
                underline: const SizedBox(),
                items: [
                  for (final h in [5, 6, 7, 8, 9, 10])
                    DropdownMenuItem(value: h, child: Text('$h الصبح')),
                ],
                onChanged: (h) =>
                    ref.read(reminderSettingsProvider.notifier).update(hour: h),
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.nights_stay_outlined),
            title: const Text('تذكير صيام الاتنين والخميس'),
            subtitle: const Text('بالليل قبلها'),
            value: reminders.fastingMonThu,
            onChanged: (v) =>
                ref.read(reminderSettingsProvider.notifier).update(monThu: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_3_outlined),
            title: const Text('تذكير الأيام البيض'),
            subtitle: const Text('13 و14 و15 من كل شهر هجري (حسب التقويم)'),
            value: reminders.fastingWhiteDays,
            onChanged: (v) =>
                ref.read(reminderSettingsProvider.notifier).update(white: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.rate_review_outlined),
            title: const Text('تذكير المراجعة الأسبوعية'),
            subtitle: const Text('كل جمعة الساعة 8 بالليل'),
            value: reminders.weeklyReview,
            onChanged: (v) =>
                ref.read(reminderSettingsProvider.notifier).update(review: v),
          ),
        ],
      ),
    );
  }
}
