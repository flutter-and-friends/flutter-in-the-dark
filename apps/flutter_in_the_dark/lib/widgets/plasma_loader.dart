import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loading indicator shown when the admin flips a challenger to Code/Widget
/// before generation+compilation is `ready` (§6.C step 6): a slowly
/// breathing plasma sphere, equivalent to lohnn/oss_player's
/// plasma_sphere_widget, with a status caption underneath.
class PlasmaLoader extends StatefulWidget {
  const PlasmaLoader({super.key, this.label = 'Generating…'});

  final String label;

  @override
  State<PlasmaLoader> createState() => _PlasmaLoaderState();
}

class _PlasmaLoaderState extends State<PlasmaLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: const Size(120, 120),
              painter: _PlasmaPainter(t: _controller.value),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.label,
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PlasmaPainter extends CustomPainter {
  _PlasmaPainter({required this.t});

  /// 0..1, one full breathing cycle.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide / 2;
    final paint = Paint()..blendMode = BlendMode.plus;

    // Three overlapping, phase-shifted blobs additive-blended into a plasma
    // ball. Deterministic and cheap — no shaders, works in CanvasKit.
    for (var i = 0; i < 3; i++) {
      final phase = t * 2 * math.pi + (i * 2 * math.pi / 3);
      final wobble = 0.75 + 0.25 * math.sin(phase * 2);
      final radius = baseRadius * (0.55 + 0.18 * i) * wobble;
      final offset = Offset(
        center.dx + baseRadius * 0.25 * math.cos(phase),
        center.dy + baseRadius * 0.25 * math.sin(phase * 1.3),
      );
      paint.shader = RadialGradient(
        colors: [
          const Color(0xFF58A6FF).withValues(alpha: 0.85 - i * 0.2),
          const Color(0xFFBC8CF8).withValues(alpha: 0.35 - i * 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: offset, radius: radius),
      );
      canvas.drawCircle(offset, radius, paint);
    }

    // Core.
    paint.shader = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.9),
        const Color(0xFF58A6FF).withValues(alpha: 0.4),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromCircle(center: center, radius: baseRadius * 0.45),
    );
    canvas.drawCircle(center, baseRadius * 0.45, paint);
  }

  @override
  bool shouldRepaint(_PlasmaPainter oldDelegate) => oldDelegate.t != t;
}
