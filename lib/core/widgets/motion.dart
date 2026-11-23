import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/palettes.dart';

/// ظهور تدريجي من تحت لفوق مع تأخير بسيط (للكروت في الشاشات)
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;

  /// ترتيب العنصر: كل عنصر بيتأخر 60ms عن اللي قبله
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _base = 420;
  static const _step = 60;
  // التأخير جزء من المنحنى (Interval) بدل Timer، فمفيش timers معلقة
  late final int _delay = _step * widget.index.clamp(0, 8);
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _base + _delay),
  )..forward();
  late final _curve = CurvedAnimation(
    parent: _c,
    curve: Interval(_delay / (_base + _delay), 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}

/// بيلف عناصر القائمة بظهور تدريجي متتابع (المسافات الفاضية بتفضل زي ما هي)
List<Widget> staggered(List<Widget> children) {
  var i = 0;
  return [
    for (final c in children)
      if (c is SizedBox || c is Divider)
        c
      else
        FadeSlideIn(index: i++, child: c),
  ];
}

/// نطّة صغيرة لما القيمة تتغير (مثلًا لما تعلّم على مهمة أو عادة)
class PopOnChange extends StatefulWidget {
  const PopOnChange({super.key, required this.value, required this.child});
  final Object value;
  final Widget child;

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = _c.value;
      final scale = 1 + 0.25 * math.sin(t * math.pi);
      return Transform.scale(scale: _c.isAnimating ? scale : 1, child: child);
    },
    child: widget.child,
  );
}

/// احتفال صغير (قصاصات ذهبي وخضرا) فوق الشاشة لمدة ثانية ونص
void showCelebration(BuildContext context) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final palette = context.palette;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _Confetti(
        colors: [palette.accent, palette.primary, palette.text],
        onDone: () => entry.remove(),
      ),
    ),
  );
  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.colors, required this.onDone});
  final List<Color> colors;
  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward().whenComplete(widget.onDone);
  final _rnd = math.Random();
  late final _pieces = List.generate(
    60,
    (_) => (
      x: _rnd.nextDouble(),
      speed: 0.6 + _rnd.nextDouble() * 0.8,
      drift: (_rnd.nextDouble() - 0.5) * 0.3,
      size: 5 + _rnd.nextDouble() * 6,
      spin: _rnd.nextDouble() * math.pi * 4,
      color: widget.colors[_rnd.nextInt(widget.colors.length)],
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _ConfettiPainter(_pieces, _c.value),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<
    ({
      double x,
      double speed,
      double drift,
      double size,
      double spin,
      Color color,
    })
  >
  pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
    for (final p in pieces) {
      final y = -20 + (size.height * 0.9) * t * p.speed;
      final x = size.width * (p.x + p.drift * t);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        ),
        Paint()..color = p.color.withValues(alpha: fade.clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
