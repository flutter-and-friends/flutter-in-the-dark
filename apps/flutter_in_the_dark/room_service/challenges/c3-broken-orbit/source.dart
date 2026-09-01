// name: Broken Orbit
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const BrokenOrbitApp());

class BrokenOrbitApp extends StatelessWidget {
  const BrokenOrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF101418),
        body: CustomPaint(painter: BrokenOrbitPainter(), child: SizedBox.expand()),
      ),
    );
  }
}

/// Eighteen dots on a perfect circle, equally spaced — except position 4 is
/// missing entirely, position 9 is pushed outward off the ring, and position
/// 14 is drawn as a stroked square instead of a dot. A thin broken ring
/// sketches the intended orbit. One-way doors: angle order, clockwise sweep.
class BrokenOrbitPainter extends CustomPainter {
  const BrokenOrbitPainter();

  static const int dotCount = 18;
  static const int missingIndex = 4;
  static const int pushedIndex = 9;
  static const int squareIndex = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.34;
    final dotPaint = Paint()..color = const Color(0xFFE8E4D8);
    final oddPaint = Paint()
      ..color = const Color(0xFFE86A5C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final tickPaint = Paint()
      ..color = const Color(0xFF3A4550)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < dotCount; i++) {
      // Angle 0 points straight up; dots advance clockwise.
      final angle = (i / dotCount) * 2 * math.pi - math.pi / 2;
      if (i == missingIndex) {
        // Faint radial tick where the dot should have been.
        final inner = Offset(
          center.dx + (radius - 8) * math.cos(angle),
          center.dy + (radius - 8) * math.sin(angle),
        );
        final outer = Offset(
          center.dx + (radius + 8) * math.cos(angle),
          center.dy + (radius + 8) * math.sin(angle),
        );
        canvas.drawLine(inner, outer, tickPaint);
        continue;
      }
      final r = i == pushedIndex ? radius * 1.28 : radius;
      final p = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      if (i == squareIndex) {
        // The square is axis-aligned, not rotated to the orbit tangent.
        canvas.drawRect(Rect.fromCenter(center: p, width: 17, height: 17), oddPaint);
      } else {
        final dotRadius = i == pushedIndex ? 11.0 : 6.5;
        canvas.drawCircle(p, dotRadius, dotPaint);
      }
    }

    // Broken guide ring: arcs sweep clockwise through each dot, with a gap
    // centered on every dot's angle. One tiny arc in the missing gap.
    final ringPaint = Paint()
      ..color = const Color(0xFF3A4550)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    const seg = 2 * math.pi / dotCount;
    for (var i = 0; i < dotCount; i++) {
      final a0 = i * seg + seg * 0.22 - math.pi / 2;
      final sweep = i == missingIndex ? seg * 0.18 : seg * 0.56;
      canvas.drawArc(ringRect, a0, sweep, false, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BrokenOrbitPainter oldDelegate) => false;
}
