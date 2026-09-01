// name: Bioluminescent Tide
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

void main() {
  runApp(const BioluminescentTideApp());
}

class BioluminescentTideApp extends StatelessWidget {
  const BioluminescentTideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const TideScreen(),
    );
  }
}

class TideScreen extends StatefulWidget {
  const TideScreen({super.key});

  @override
  State<TideScreen> createState() => _TideScreenState();
}

class _TideScreenState extends State<TideScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02101A),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _TidePainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Organism {
  const _Organism(
      this.x, this.y, this.radius, this.hue, this.phase, this.drift);

  final double x; // base horizontal position, fraction of width
  final double y; // vertical position, fraction of height
  final double radius; // bell radius, fraction of min(width, height)
  final double hue; // 0.0 = cyan, 1.0 = violet
  final double phase; // pulse phase offset
  final double drift; // horizontal sway amplitude, fraction of width
}

class _TidePainter extends CustomPainter {
  _TidePainter(this.t);

  /// Animation phase in [0, 1).
  final double t;

  static const _organisms = [
    _Organism(0.16, 0.30, 0.085, 0.15, 0.00, 0.012),
    _Organism(0.34, 0.52, 0.060, 0.55, 0.31, 0.020),
    _Organism(0.52, 0.22, 0.100, 0.30, 0.62, 0.016),
    _Organism(0.68, 0.44, 0.052, 0.80, 0.14, 0.024),
    _Organism(0.84, 0.28, 0.075, 0.05, 0.47, 0.014),
    _Organism(0.44, 0.72, 0.044, 0.65, 0.78, 0.028),
    _Organism(0.90, 0.66, 0.058, 0.40, 0.90, 0.018),
    _Organism(0.10, 0.68, 0.040, 0.90, 0.55, 0.022),
  ];

  Color _bellColor(_Organism o, double opacity) {
    return Color.lerp(
      const Color(0xFF38F5E1),
      const Color(0xFF9D5CFF),
      o.hue,
    )!
        .withOpacity(opacity);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final m = math.min(w, h);
    final time = t;

    // 1. Water column: abyssal blue with a faint green upwelling below.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, h),
          const [
            Color(0xFF021A2B),
            Color(0xFF01121F),
            Color(0xFF010B14),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 2. God-rays: faint slanted light shafts from the surface.
    for (var i = 0; i < 5; i++) {
      final x0 = w * (0.12 + i * 0.19);
      final sway = 14 * math.sin(2 * math.pi * (time + i * 0.31));
      final shaft = Path()
        ..moveTo(x0 + sway, 0)
        ..lineTo(x0 + sway + w * 0.045, 0)
        ..lineTo(x0 + sway + w * 0.11, h * 0.62)
        ..lineTo(x0 + sway - w * 0.05, h * 0.62)
        ..close();
      canvas.drawPath(
        shaft,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x0, 0),
            Offset(x0, h * 0.62),
            [
              const Color(0xFF1E6E8C).withOpacity(0.16),
              const Color(0xFF1E6E8C).withOpacity(0.0),
            ],
          ),
      );
    }

    // 3. Organisms: glowing bells with trailing tendrils, pulsing.
    for (final o in _organisms) {
      final pulse = 0.72 + 0.28 * math.sin(2 * math.pi * (time + o.phase));
      final cx =
          (o.x + o.drift * math.sin(2 * math.pi * (time * 1.3 + o.phase))) * w;
      final cy = o.y * h + 10 * math.sin(2 * math.pi * (time + o.phase * 2));
      final r = o.radius * m * pulse;

      // Halo.
      canvas.drawCircle(
        Offset(cx, cy),
        r * 2.6,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            r * 2.6,
            [
              _bellColor(o, 0.30 * pulse),
              _bellColor(o, 0.0),
            ],
          ),
      );

      // Bell: stacked translucent domes for a jellyfish-bell feel.
      final bellPath = Path()
        ..moveTo(cx - r, cy)
        ..cubicTo(cx - r, cy - r * 1.15, cx + r, cy - r * 1.15, cx + r, cy)
        ..quadraticBezierTo(cx, cy + r * 0.35, cx - r, cy)
        ..close();
      canvas.drawPath(
        bellPath,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy - r * 0.35),
            r * 1.4,
            [
              Colors.white.withOpacity(0.65 * pulse),
              _bellColor(o, 0.85 * pulse),
              _bellColor(o, 0.10 * pulse),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );

      // Inner organ ring.
      canvas.drawCircle(
        Offset(cx, cy - r * 0.25),
        r * 0.30,
        Paint()
          ..color = Colors.white.withOpacity(0.35 * pulse)
          ..blendMode = BlendMode.plus,
      );

      // Tendrils: three sinusoidal trails below the bell.
      for (var k = -1; k <= 1; k++) {
        final tendril = Path();
        final baseX = cx + k * r * 0.45;
        tendril.moveTo(baseX, cy + r * 0.12);
        const segs = 22;
        for (var s = 1; s <= segs; s++) {
          final f = s / segs;
          final swayX = r *
              0.30 *
              math.sin(2 * math.pi * (f * 1.6 + time * 1.8 + o.phase + k));
          tendril.lineTo(baseX + swayX * f, cy + r * 0.12 + f * r * 2.6);
        }
        canvas.drawPath(
          tendril,
          Paint()
            ..color = _bellColor(o, (0.45 - k.abs() * 0.12) * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..blendMode = BlendMode.plus
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
      }
    }

    // 4. Particulate plankton: tiny drifting motes.
    final rng = math.Random(42);
    final motePaint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 120; i++) {
      final px = rng.nextDouble();
      final py = rng.nextDouble();
      final size = 0.8 + rng.nextDouble() * 1.6;
      final glow =
          0.25 + 0.30 * math.sin(2 * math.pi * (time * 2 + px * 5 + py * 3));
      motePaint.color =
          const Color(0xFF7FE8DC).withOpacity(glow.clamp(0.0, 1.0));
      final driftX = 8 * math.sin(2 * math.pi * (time + py));
      canvas.drawCircle(
        Offset(px * w + driftX, py * h),
        size,
        motePaint,
      );
    }

    // 5. Seabed glow: soft teal breath along the bottom edge.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.88, w, h * 0.12),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.88),
          Offset(0, h),
          [
            const Color(0xFF0B3B3E).withOpacity(0.0),
            const Color(0xFF0E5A57).withOpacity(0.35),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_TidePainter oldDelegate) => oldDelegate.t != t;
}
