import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/session.dart';
import '../../core/notifications.dart';
import '../../core/widgets/palette_picker.dart';
import '../account/account_data.dart';
import '../account/backup_restore.dart';
import '../reminders/smart_reminders.dart';
import '../account/privacy_screen.dart';
import '../lock/lock_service.dart';
import '../lock/pin_setup_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final lock = ref.watch(lockProvider);
    final reminders = ref.watch(reminderSettingsProvider);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        children: [
          section('الأقسام'),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('مساعد حياتي'),
            onTap: () => context.push('/assistant'),
          ),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: const Text('عاداتي'),
            onTap: () => context.push('/more/habits'),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('وضع التركيز'),
            onTap: () => context.push('/focus'),
          ),
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: const Text('يومياتي'),
            onTap: () => context.push('/more/journal'),
          ),
          ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: const Text('مناسباتي وأهلي'),
            onTap: () => context.push('/more/occasions'),
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('إحصائياتي'),
            onTap: () => context.push('/more/stats'),
          ),
          section('الحساب'),
          if (session is UserSession)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(session.name ?? 'حسابي'),
              subtitle: session.email == null ? null : Text(session.email!),
            )
          else
            const ListTile(
              leading: Icon(Icons.phone_android),
              title: Text('وضع الضيف'),
              subtitle: Text('بياناتك محفوظة على الموبايل ده بس'),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(
              session is UserSession ? 'تسجيل الخروج' : 'تسجيل الدخول بحساب',
            ),
            onTap: () => ref.read(sessionProvider.notifier).signOut(),
          ),
          section('الأمان والمظهر'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('قفل التطبيق برمز'),
            subtitle: lock.biometrics ? const Text('البصمة مفعّلة') : null,
            value: lock.enabled,
            onChanged: (v) {
              if (v) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PinSetupScreen(),
                  ),
                );
              } else {
                ref.read(lockProvider.notifier).disable();
              }
            },
          ),
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('الثيم'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: PalettePicker(),
          ),
          section('التنبيهات'),
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
          section('بياناتي'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('تصدير بياناتي'),
            subtitle: const Text('ملف فيه كل حاجة سجّلتها'),
            onTap: () async {
              try {
                await exportMyData(ref);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذّر التصدير، جرّب تاني')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('استرجاع من نسخة احتياطية'),
            subtitle: const Text(
              'اختار ملف التصدير وهنرجّع بياناتك (من غير ما نمسح حاجة)',
            ),
            onTap: () async {
              try {
                final n = await pickAndRestore(ref);
                if (n != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('رجّعنا $n عنصر ✓')));
                }
              } on FormatException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تعذّر الاسترجاع، اتأكد من الملف'),
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('الخصوصية'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              session is UserSession
                  ? 'حذف حسابي وكل بياناتي'
                  : 'مسح كل البيانات من الموبايل',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmDelete(context, ref),
          ),
          const SizedBox(height: 24),
          const Center(child: Text('حياتي • الإصدار 0.1.0')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('متأكد؟'),
        content: const Text(
          'كل مهامك وعاداتك وصلواتك وفلوسك ويومياتك هتتمسح نهائيًا، ومش هينفع ترجعها. يُفضّل تصدّر بياناتك الأول.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('لا، رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(d).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('امسح نهائيًا'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteMyAccount(ref);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر الحذف، اتأكد من النت وجرّب تاني'),
          ),
        );
      }
    }
  }
}
