// name: Ember Drift
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

void main() {
  runApp(const EmberApp());
}

class EmberApp extends StatelessWidget {
  const EmberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const EmberScreen(),
    );
  }
}

class EmberScreen extends StatefulWidget {
  const EmberScreen({super.key});

  @override
  State<EmberScreen> createState() => _EmberScreenState();
}

class _EmberScreenState extends State<EmberScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
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
      backgroundColor: const Color(0xFF080610),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _EmberPainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _EmberSpec {
  const _EmberSpec({
    required this.x,
    required this.offset,
    required this.speed,
    required this.size,
    required this.swayAmp,
    required this.swayFreq,
    required this.phase,
    required this.heat,
  });

  /// Base horizontal position, fraction of width.
  final double x;

  /// Life-cycle offset in [0, 1) so embers are staggered through the loop.
  final double offset;

  /// Vertical rise speed: fraction of height climbed per full loop.
  final double speed;

  /// Ember core radius in logical pixels.
  final double size;

  /// Horizontal sway amplitude, fraction of width.
  final double swayAmp;

  /// Sway oscillations per rise cycle.
  final double swayFreq;

  /// Sway phase.
  final double phase;

  /// 0 = deep red coal, 1 = near-white hot.
  final double heat;
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.t);

  /// Animation phase in [0, 1).
  final double t;

  static final math.Random _rng = math.Random(23);
  static final List<_EmberSpec> _embers = [
    for (var i = 0; i < 90; i++)
      _EmberSpec(
        x: _rng.nextDouble(),
        offset: _rng.nextDouble(),
        speed: 0.45 + _rng.nextDouble() * 0.75,
        size: 0.9 + _rng.nextDouble() * 2.1,
        swayAmp: 0.006 + _rng.nextDouble() * 0.030,
        swayFreq: 0.6 + _rng.nextDouble() * 1.8,
        phase: _rng.nextDouble() * 2 * math.pi,
        heat: _rng.nextDouble(),
      ),
  ];

  /// Ember life fraction in [0, 1) for the current loop time.
  double _life(_EmberSpec e) => (t * e.speed + e.offset) % 1.0;

  /// Fade in fast, fade out slowly toward the top of the climb.
  double _envelope(double life) {
    final fadeIn = (life / 0.08).clamp(0.0, 1.0);
    final fadeOut = 1.0 - ((life - 0.55) / 0.45).clamp(0.0, 1.0);
    return fadeIn * fadeOut;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Sky: near-black plum cooling to a faint warm ember glow at the
    //    horizon, as if a fire sits just below the frame.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, h),
          const [
            Color(0xFF05040C),
            Color(0xFF0B0714),
            Color(0xFF160C18),
            Color(0xFF2A1414),
          ],
          const [0.0, 0.45, 0.75, 1.0],
        ),
    );

    // 2. Soft warm bloom hugging the ground line, breathing slowly.
    final breathe = 0.75 + 0.25 * math.sin(2 * math.pi * t * 2.0);
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h),
          Offset(0, h * 0.62),
          [
            const Color(0xFFFF5A1F).withOpacity(0.22 * breathe),
            const Color(0xFFFF5A1F).withOpacity(0.0),
          ],
        ),
    );

    // 3. Hills: two smooth silhouette ridges in near-black browns.
    void ridge(
      double baseY,
      double amp,
      double freq,
      double phase,
      Color color,
    ) {
      final path = Path()..moveTo(0, h);
      for (var i = 0; i <= 60; i++) {
        final u = i / 60;
        final y = baseY +
            amp * math.sin(2 * math.pi * (freq * u) + phase) +
            amp * 0.4 * math.sin(2 * math.pi * (freq * 2.7 * u) + phase * 1.6);
        path.lineTo(u * w, y * h);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    ridge(0.84, 0.045, 1.6, 0.8, const Color(0xFF120A10));
    ridge(0.93, 0.030, 2.3, 2.4, const Color(0xFF080409));

    // 4. Embers: additive-blended dots with a blurred halo. Each climbs,
    //    sways sideways, flickers, and cools from white-hot to dull red.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final e in _embers) {
      final life = _life(e);
      final y = h * (1.02 - life * 0.92);
      final x = (e.x +
              e.swayAmp *
                  math.sin(2 * math.pi * e.swayFreq * life + e.phase)) *
          w;

      // Individual flicker: quick pseudo-random shimmer plus a slow pulse.
      final flicker = 0.72 +
          0.28 *
              math.sin(2 * math.pi * (t * 7.0 + e.phase * 3.1)) *
              math.sin(2 * math.pi * (t * 3.0 + e.phase));
      final alpha = (_envelope(life) * flicker).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      // Cool as the ember climbs: hot cores start near-white, end deep red.
      final cool = Color.lerp(
        const Color(0xFFFFF1C4),
        const Color(0xFFFF7A26),
        (e.heat * 0.6 + life * 0.5).clamp(0.0, 1.0),
      )!;
      final outer = Color.lerp(
        const Color(0xFFFFB03A),
        const Color(0xFF7A1E08),
        life,
      )!;

      // Halo: wide, blurred, faint.
      canvas.drawCircle(
        Offset(x, y),
        e.size * 4.5,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = outer.withOpacity(alpha * 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core: small, bright.
      canvas.drawCircle(
        Offset(x, y),
        e.size,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = cool.withOpacity(alpha * 0.9),
      );

      // Occasionally an ember sheds a short fading trail above itself.
      if (e.heat > 0.72) {
        final trailPaint = Paint()
          ..blendMode = BlendMode.plus
          ..strokeWidth = e.size * 0.9
          ..strokeCap = StrokeCap.round
          ..color = outer.withOpacity(alpha * 0.25);
        canvas.drawLine(
          Offset(x, y - e.size * 1.5),
          Offset(x, y - e.size * (5 + 7 * life)),
          trailPaint,
        );
      }
    }
    canvas.restore();

    // 5. A few near-foreground soot motes drifting DOWN against the rise,
    //    barely visible, to give the air some depth.
    final sootPaint = Paint();
    for (var i = 0; i < 14; i++) {
      final seed = i * 37.7;
      final life = (t * 0.30 + i / 14) % 1.0;
      final x = ((seed * 0.61803) % 1.0 +
              0.012 * math.sin(2 * math.pi * life * 1.3 + seed)) *
          w;
      final y = h * (life * 0.85 + 0.05);
      sootPaint.color =
          const Color(0xFF3A3230).withOpacity(0.35 * (1.0 - life));
      canvas.drawCircle(Offset(x, y), 1.1, sootPaint);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter oldDelegate) => oldDelegate.t != t;
}
