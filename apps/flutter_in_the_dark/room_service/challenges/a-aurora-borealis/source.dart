// name: Aurora Borealis
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

void main() {
  runApp(const AuroraApp());
}

class AuroraApp extends StatelessWidget {
  const AuroraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const AuroraScreen(),
    );
  }
}

class AuroraScreen extends StatefulWidget {
  const AuroraScreen({super.key});

  @override
  State<AuroraScreen> createState() => _AuroraScreenState();
}

class _AuroraScreenState extends State<AuroraScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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
      backgroundColor: const Color(0xFF040711),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _AuroraPainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);

  /// Animation phase in [0, 1).
  final double t;

  static final math.Random _rng = math.Random(7);
  static final List<Offset> _stars = [
    for (var i = 0; i < 240; i++) Offset(_rng.nextDouble(), _rng.nextDouble()),
  ];

  double _ribbonY(double u, int layer, double time) {
    final phase = layer * 2.39;
    return 0.16 +
        layer * 0.055 +
        0.055 * math.sin(2 * math.pi * (1.7 * u + time) + phase) +
        0.030 * math.sin(2 * math.pi * (3.1 * u - time * 1.4) + phase * 1.7) +
        0.012 * math.sin(2 * math.pi * (6.3 * u + time * 0.6) + phase * 2.3);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final time = t;

    // 1. Sky: deep indigo with a faint teal horizon glow.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, h),
          const [
            Color(0xFF03050E),
            Color(0xFF071226),
            Color(0xFF0A1F38),
            Color(0xFF0D2E4A),
          ],
          const [0.0, 0.45, 0.75, 1.0],
        ),
    );

    // 2. Stars with varying magnitude and warm/cool tints.
    final starPaint = Paint();
    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      if (s.dy > 0.62) continue;
      final mag = (i * 7919) % 100 / 100.0;
      final twinkle = 0.55 + 0.45 * math.sin(2 * math.pi * (time + mag * 3.7));
      final alpha = (0.25 + 0.75 * mag) * twinkle * (1.0 - s.dy);
      starPaint.color = Color.lerp(
        const Color(0xFF9FB8FF),
        const Color(0xFFFFF3D6),
        mag,
      )!
          .withOpacity(alpha.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(s.dx * w, s.dy * h),
        0.6 + mag * 1.5,
        starPaint,
      );
    }

    // 3. Aurora ribbons: stacked soft strokes between two noisy waves,
    //    additive-blended in three chromatic bands.
    final ribbons = [
      (layer: 0, color: const Color(0xFF35FF9E), thickness: 150.0),
      (layer: 1, color: const Color(0xFF2FD8C9), thickness: 120.0),
      (layer: 2, color: const Color(0xFF8A5BFF), thickness: 100.0),
      (layer: 3, color: const Color(0xFF3FA7FF), thickness: 80.0),
    ];
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final ribbon in ribbons) {
      const steps = 90;
      // Soft vertical falloff inside the ribbon band.
      for (var band = 0; band < 14; band++) {
        final f = band / 14;
        final paint = Paint()
          ..blendMode = BlendMode.plus
          ..color = ribbon.color
              .withOpacity((0.055 * (1 - (f - 0.35).abs())).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = ribbon.thickness / 13
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
        final bandPath = Path();
        for (var i = 0; i <= steps; i++) {
          final u = i / steps;
          final x = u * w;
          final y = (_ribbonY(u, ribbon.layer, time) + 0.012) * h +
              ribbon.thickness * f * 0.85;
          if (i == 0) {
            bandPath.moveTo(x, y);
          } else {
            bandPath.lineTo(x, y);
          }
        }
        canvas.drawPath(bandPath, paint);
      }
    }
    canvas.restore();

    // 4. Mountain silhouettes: two jagged ridgelines in near-black blues.
    void ridge(double baseY, double jag, Color color, int seed) {
      final r = math.Random(seed);
      var y = baseY;
      final path = Path()..moveTo(0, h);
      var x = 0.0;
      path.lineTo(0, y * h);
      while (x < w) {
        final step = 26 + r.nextDouble() * 54;
        y = (baseY + (r.nextDouble() - 0.5) * jag).clamp(0.52, 0.97);
        path.lineTo(math.min(x + step, w), y * h);
        x += step;
      }
      path
        ..lineTo(w, y * h)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    ridge(0.72, 0.20, const Color(0xFF0A1626), 11);
    ridge(0.84, 0.16, const Color(0xFF050B16), 23);

    // 5. Aurora reflection shimmer on the low ground band.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.90, w, h * 0.10),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.90),
          Offset(0, h),
          [
            const Color(0xFF35FF9E).withOpacity(0.10),
            const Color(0xFF35FF9E).withOpacity(0.0),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.t != t;
}
