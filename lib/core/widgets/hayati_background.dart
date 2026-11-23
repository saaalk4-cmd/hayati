import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/palettes.dart';

/// خلفية التطبيق: تدرّج الثيم + نقشة هندسية إسلامية خفيفة جدًا
class HayatiBackground extends StatelessWidget {
  const HayatiBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: p.background),
      child: CustomPaint(
        painter: _StarPatternPainter(
          p.accent.withValues(alpha: p.isDark ? 0.05 : 0.07),
        ),
        child: child,
      ),
    );
  }
}

/// نجوم ثمانية متكررة (شكل زخرفي إسلامي بسيط)
class _StarPatternPainter extends CustomPainter {
  _StarPatternPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 96.0;
    for (var y = -step / 2; y < size.height + step; y += step) {
      for (var x = -step / 2; x < size.width + step; x += step) {
        _star(canvas, Offset(x, y), 22, paint);
      }
    }
  }

  void _star(Canvas c, Offset o, double r, Paint p) {
    // مربعين متراكبين بزاوية 45° = نجمة ثمانية
    for (final rot in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = rot + i * math.pi / 2 + math.pi / 4;
        final pt = o + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      c.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_StarPatternPainter old) => old.color != color;
}

/// انتقال بين الشاشات: كل شاشة بترسم خلفيتها (التدرّج) فمفيش تداخل وقت الحركة
class HayatiPageTransitionsBuilder extends PageTransitionsBuilder {
  const HayatiPageTransitionsBuilder();

  static const _inner = FadeForwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    HayatiBackground(child: child),
  );
}
