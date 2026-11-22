import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import 'prayer_settings.dart';

class QiblaScreen extends ConsumerWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerSettingsProvider);
    final qibla = Qibla(settings.coordinates).direction;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snap) {
          final heading = snap.data?.heading;
          final noSensor = snap.connectionState == ConnectionState.active &&
              heading == null;
          final angle = ((qibla - (heading ?? 0)) * math.pi / 180);
          final aligned = heading != null &&
              ((qibla - heading + 540) % 360 - 180).abs() < 5;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'القبلة على ${qibla.toStringAsFixed(0)}° من الشمال',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(settings.placeLabel, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: aligned ? AppColors.gold500 : AppColors.emerald700,
                          width: aligned ? 6 : 3,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: angle / (2 * math.pi),
                      duration: const Duration(milliseconds: 200),
                      child: const Column(
                        children: [
                          Icon(Icons.navigation, size: 96, color: AppColors.gold500),
                          Spacer(),
                        ],
                      ),
                    ),
                    const Icon(Icons.mosque, size: 56, color: AppColors.emerald700),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                noSensor
                    ? 'موبايلك مفيهوش بوصلة. استخدم الزاوية المكتوبة فوق مع بوصلة خارجية.'
                    : heading == null
                        ? 'جاري تشغيل البوصلة...'
                        : aligned
                            ? 'إنت متجه للقبلة ✓'
                            : 'لفّ الموبايل لحد ما السهم الذهبي يبقى لفوق',
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'امسك الموبايل مفرود وبعيد عن المعادن والمغناطيس عشان البوصلة تبقى دقيقة.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
