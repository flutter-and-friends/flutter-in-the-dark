// name: Neon Grid Horizon
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

void main() {
  runApp(const NeonGridApp());
}

class NeonGridApp extends StatelessWidget {
  const NeonGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const NeonGridScreen(),
    );
  }
}

class NeonGridScreen extends StatefulWidget {
  const NeonGridScreen({super.key});

  @override
  State<NeonGridScreen> createState() => _NeonGridScreenState();
}

class _NeonGridScreenState extends State<NeonGridScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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
      backgroundColor: const Color(0xFF0B0218),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _NeonGridPainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _NeonGridPainter extends CustomPainter {
  _NeonGridPainter(this.t);

  /// Animation phase in [0, 1); drives the grid's forward scroll.
  final double t;

  static const _horizon = 0.52;
  static const _sunCenter = 0.40;
  static const _sunRadius = 0.185;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizonY = h * _horizon;
    final sunCenter = Offset(w * 0.5, h * _sunCenter);
    final sunR = w * _sunRadius;

    // 1. Sky: black-violet to hot magenta behind the sun.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizonY + 1),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, horizonY),
          const [
            Color(0xFF08011A),
            Color(0xFF1B0433),
            Color(0xFF3B0A54),
            Color(0xFF6E1470),
          ],
          const [0.0, 0.4, 0.75, 1.0],
        ),
    );

    // 2. Haze glow bleeding up from the horizon line.
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - h * 0.16, w, h * 0.16),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonY - h * 0.16),
          Offset(0, horizonY),
          [
            const Color(0xFFFF2E88).withOpacity(0.0),
            const Color(0xFFFF2E88).withOpacity(0.38),
          ],
        ),
    );

    // 3. Sun: vertical gradient disc clipped, with horizontal scanline gaps
    //    that widen toward the bottom of the disc.
    final sunGradient = Paint()
      ..shader = ui.Gradient.linear(
        sunCenter - Offset(0, sunR),
        sunCenter + Offset(0, sunR),
        const [
          Color(0xFFFFE259),
          Color(0xFFFFA751),
          Color(0xFFFF5E7E),
          Color(0xFFFF2E88),
        ],
        const [0.0, 0.45, 0.8, 1.0],
      );
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        sunCenter,
        sunR * 1.9,
        [
          const Color(0xFFFF2E88).withOpacity(0.35),
          const Color(0xFFFF2E88).withOpacity(0.0),
        ],
      );
    canvas.drawCircle(sunCenter, sunR * 1.9, glowPaint);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
    final gapStart = 0.30; // fraction of radius where gaps begin
    const gapRows = 9;
    for (var i = 0; i < gapRows; i++) {
      final f0 = gapStart + (1 - gapStart) * (i / gapRows);
      final f1 = gapStart + (1 - gapStart) * ((i + 1) / gapRows);
      final y0 = sunCenter.dy + f0 * sunR;
      final thickness = 2.0 + f0 * f0 * 11.0;
      // Slice of the sun between y0 and the next band.
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, y0, w, (f1 - f0) * sunR - thickness));
      canvas.drawCircle(sunCenter, sunR, sunGradient);
      canvas.restore();
    }
    // The top portion above the gaps is drawn whole.
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, w, sunCenter.dy + (gapStart - 0.02) * sunR));
    canvas.drawCircle(sunCenter, sunR, sunGradient);
    canvas.restore();
    canvas.restore();

    // 4. Perspective grid below the horizon: cyan, additive glow.
    final gridPaint = Paint()
      ..color = const Color(0xFF23E6FF).withOpacity(0.85)
      ..strokeWidth = 1.4
      ..blendMode = BlendMode.plus;
    final gridGlow = Paint()
      ..color = const Color(0xFF23E6FF).withOpacity(0.28)
      ..strokeWidth = 5.0
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Verticals: rays converging on the vanishing point at screen centre.
    final vanish = Offset(w * 0.5, horizonY);
    const spokes = 26;
    for (var i = -spokes; i <= spokes; i++) {
      final xBottom = w * 0.5 + i * w * 0.09;
      canvas.drawLine(vanish, Offset(xBottom, h), gridGlow);
      canvas.drawLine(vanish, Offset(xBottom, h), gridPaint);
    }

    // Horizontals: exponential spacing marching toward the viewer; t scrolls.
    const rows = 18;
    for (var i = 0; i < rows; i++) {
      final k = (i + (1 - t)) / rows;
      final y = horizonY + (h - horizonY) * math.pow(k, 2.6);
      final fade = (0.25 + 0.75 * k).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..color = const Color(0xFF23E6FF).withOpacity(0.85 * fade)
          ..strokeWidth = 1.4
          ..blendMode = BlendMode.plus,
      );
    }

    // 5. Horizon line: hot white-pink core with magenta bloom.
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(w, horizonY),
      Paint()
        ..color = const Color(0xFFFF2E88).withOpacity(0.55)
        ..strokeWidth = 9
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(w, horizonY),
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..strokeWidth = 1.6
        ..blendMode = BlendMode.plus,
    );

    // 6. Ground vignette: darken the extreme bottom corners.
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, h - horizonY),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonY),
          Offset(0, h),
          [
            const Color(0xFF000000).withOpacity(0.0),
            const Color(0xFF000000).withOpacity(0.45),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_NeonGridPainter oldDelegate) => oldDelegate.t != t;
}
