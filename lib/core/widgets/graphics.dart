import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/palettes.dart';

/// حلقة تقدّم متحركة بتدرّج ذهبي (زي حلقات الساعات الذكية)
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 44,
    this.stroke = 5,
    this.child,
    this.colors,
  });

  /// من 0 لـ 1 (أكتر من 1 بيتعرض كاملة)
  final double value;
  final double size;
  final double stroke;
  final Widget? child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c =
        colors ??
        [p.accent.withValues(alpha: 0.6), p.accent, AppColors.gold200];
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, inner) => CustomPaint(
          painter: _RingPainter(v, stroke, c, p.text.withValues(alpha: 0.1)),
          child: Center(child: inner),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.colors, this.track);
  final double value;
  final double stroke;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (value <= 0) return;
    final sweep = math.pi * 2 * value;
    canvas.drawArc(
      r,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + math.pi * 2,
          colors: colors,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.colors != colors || old.track != track;
}

/// رقم بيعدّ لحد قيمته لما يظهر أو يتغيّر
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textDirection,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(
        format(v == value ? v : v.roundToDouble()),
        style: style,
        textDirection: textDirection,
      ),
    );
  }
}

/// شكل السما حسب الوقت: هلال ونجوم بالليل، شمس بتطلع الفجر، شمس النهار، وغروب
enum SkyPhase { night, dawn, day, sunset }

SkyPhase skyPhaseFor(
  DateTime now, {
  required DateTime fajr,
  required DateTime sunrise,
  required DateTime asr,
  required DateTime maghrib,
}) {
  if (now.isBefore(fajr) ||
      !now.isBefore(maghrib.add(const Duration(minutes: 20)))) {
    return SkyPhase.night;
  }
  if (now.isBefore(sunrise.add(const Duration(minutes: 20)))) {
    return SkyPhase.dawn;
  }
  if (now.isBefore(asr)) return SkyPhase.day;
  return SkyPhase.sunset;
}

class SkyMark extends StatefulWidget {
  const SkyMark({super.key, required this.phase, this.size = 56});
  final SkyPhase phase;
  final double size;

  @override
  State<SkyMark> createState() => _SkyMarkState();
}

class _SkyMarkState extends State<SkyMark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: CustomPaint(
            key: ValueKey(widget.phase),
            size: Size.square(widget.size),
            painter: _SkyPainter(widget.phase, _c),
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.phase, this.t) : super(repaint: t);
  final SkyPhase phase;
  final Animation<double> t;

  static const _gold = AppColors.gold500;
  static const _pale = AppColors.gold200;

  @override
  void paint(Canvas canvas, Size s) {
    final v = t.value;
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width * 0.3;
    switch (phase) {
      case SkyPhase.night:
        _glow(
          canvas,
          c,
          r * 1.8,
          _gold.withValues(alpha: 0.18 + 0.06 * math.sin(v * math.pi * 2)),
        );
        // هلال: دايرة دهبي ومقصوص منها دايرة
        final moon = Path()..addOval(Rect.fromCircle(center: c, radius: r));
        final cut = Path()
          ..addOval(
            Rect.fromCircle(
              center: c + Offset(r * 0.55, -r * 0.25),
              radius: r * 0.92,
            ),
          );
        canvas.drawPath(
          Path.combine(PathOperation.difference, moon, cut),
          Paint()..color = _gold,
        );
        // نجوم بتلمع
        const stars = [
          Offset(0.12, 0.18),
          Offset(0.82, 0.12),
          Offset(0.9, 0.62),
          Offset(0.22, 0.8),
        ];
        for (var i = 0; i < stars.length; i++) {
          final tw =
              0.45 +
              0.55 * (0.5 + 0.5 * math.sin((v + i * 0.27) * math.pi * 2));
          _star(
            canvas,
            Offset(stars[i].dx * s.width, stars[i].dy * s.height),
            s.width * (i.isEven ? 0.07 : 0.05),
            _pale.withValues(alpha: tw),
          );
        }
      case SkyPhase.dawn:
        final horizon = s.height * 0.72;
        _glow(
          canvas,
          Offset(c.dx, horizon),
          r * 2.2,
          const Color(0xFFFFB067).withValues(alpha: 0.35),
        );
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, s.width, horizon));
        final rise = 0.15 * math.sin(v * math.pi * 2);
        canvas.drawCircle(
          Offset(c.dx, horizon + r * (0.2 + rise)),
          r,
          Paint()..color = const Color(0xFFFFC46B),
        );
        canvas.restore();
        canvas.drawLine(
          Offset(s.width * 0.1, horizon),
          Offset(s.width * 0.9, horizon),
          Paint()
            ..color = _pale.withValues(alpha: 0.6)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      case SkyPhase.day:
        _glow(canvas, c, r * 2, const Color(0xFFFFD36B).withValues(alpha: 0.3));
        final rays = Paint()
          ..color = const Color(0xFFFFD36B)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = v * math.pi * 2 / 4 + i * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * (r * 1.25), c + d * (r * 1.6), rays);
        }
        canvas.drawCircle(
          c,
          r * 0.95,
          Paint()..color = const Color(0xFFFFCB45),
        );
      case SkyPhase.sunset:
        final horizon = s.height * 0.75;
        _glow(
          canvas,
          Offset(c.dx, horizon),
          r * 2.3,
          const Color(0xFFFF8A4C).withValues(alpha: 0.35),
        );
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, s.width, horizon));
        canvas.drawCircle(
          Offset(c.dx, horizon - r * 0.35),
          r,
          Paint()
            ..shader =
                const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFC46B), Color(0xFFFF7A45)],
                ).createShader(
                  Rect.fromCircle(
                    center: Offset(c.dx, horizon - r * 0.35),
                    radius: r,
                  ),
                ),
        );
        canvas.restore();
        for (var i = 0; i < 2; i++) {
          final y = horizon + 4 + i * 5.0;
          final w = s.width * (0.6 - i * 0.2);
          canvas.drawLine(
            Offset(c.dx - w / 2, y),
            Offset(c.dx + w / 2, y),
            Paint()
              ..color = _pale.withValues(alpha: 0.5 - i * 0.2)
              ..strokeWidth = 1.5
              ..strokeCap = StrokeCap.round,
          );
        }
    }
  }

  void _glow(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.35;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.phase != phase;
}

/// تحميل شيك: سطور رمادي بيعدّي عليها لمعان بدل الدايرة اللي بتلف
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.items = 4});
  final int items;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = p.text.withValues(alpha: 0.07);
    final shine = p.text.withValues(alpha: 0.16);
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: p.text,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [base, shine, base],
          stops: [
            (_c.value - 0.3).clamp(0, 1).toDouble(),
            _c.value,
            (_c.value + 0.3).clamp(0, 1).toDouble(),
          ],
        ).createShader(r),
        child: child,
      ),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: widget.items,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.text,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(double.infinity, 14),
                    const SizedBox(height: 8),
                    bar(120.0 + (i % 3) * 30, 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
