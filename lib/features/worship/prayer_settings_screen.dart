import 'package:adhan/adhan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'adhan_notifications.dart';
import 'prayer_service.dart';
import 'prayer_settings.dart';

class PrayerSettingsScreen extends ConsumerStatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  ConsumerState<PrayerSettingsScreen> createState() =>
      _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends ConsumerState<PrayerSettingsScreen> {
  bool _locating = false;

  Future<void> _locate() async {
    setState(() => _locating = true);
    final error =
        await ref.read(prayerSettingsProvider.notifier).detectLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'تم تحديد موقعك ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(prayerSettingsProvider);
    final times = ref.watch(todayPrayerTimesProvider);
    final notifier = ref.read(prayerSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات المواقيت')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('الموقع'),
            subtitle: Text(s.placeLabel),
            trailing: _locating
                ? const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator())
                : TextButton(onPressed: _locate, child: const Text('حدّد موقعي')),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('طريقة الحساب'),
            subtitle: Text(calculationMethodNames[s.method] ?? s.method.name),
            onTap: () async {
              final m = await showModalBottomSheet<CalculationMethod>(
                context: context,
                showDragHandle: true,
                builder: (c) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in calculationMethodNames.entries)
                        ListTile(
                          title: Text(e.value),
                          trailing: e.key == s.method
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(c, e.key),
                        ),
                    ],
                  ),
                ),
              );
              if (m != null) await notifier.setMethod(m);
            },
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('حساب العصر'),
            trailing: SegmentedButton<Madhab>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Madhab.shafi, label: Text('الجمهور')),
                ButtonSegment(value: Madhab.hanafi, label: Text('الحنفي')),
              ],
              selected: {s.madhab},
              onSelectionChanged: (v) => notifier.setMadhab(v.first),
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('إشعار الأذان'),
            subtitle: const Text('تنبيه عند دخول وقت كل صلاة'),
            value: s.adhanNotifications,
            onChanged: (v) async {
              if (v) await AdhanNotifications.instance.requestPermissions();
              await notifier.setAdhan(v);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('مواقيت النهارده',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            dense: true,
            title: const Text('الشروق'),
            trailing: Text(formatPrayerTime(times.sunrise)),
          ),
          for (final p in PrayerName.values)
            ListTile(
              dense: true,
              title: Text(p.ar),
              trailing: Text(formatPrayerTime(times[p])),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'المواقيت بتتحسب على الموبايل نفسه حسب موقعك وطريقة الحساب، وممكن تختلف دقيقة أو اتنين عن تقويم مسجدك.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
