// name: F2 - Emberbloom Mandala
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

void main() => runApp(const EmberbloomApp());

class EmberbloomApp extends StatelessWidget {
  const EmberbloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0B060E),
        body: SizedBox.expand(
          child: CustomPaint(painter: EmberbloomPainter()),
        ),
      ),
    );
  }
}

/// A static generative mandala grown from seeded pseudo-random phyllotaxis:
/// five nested ember rings in the core, a 34-spiral seed head, a 15-petal
/// lattice (teardrops with 28 inner veins each), 22 outer flame fronds with
/// 12 ember tips apiece, drifting spores, and background star dust. Every
/// coordinate falls out of one seed — the broad idea is describable, the
/// exact geometry is not.
class EmberbloomPainter extends CustomPainter {
  const EmberbloomPainter();

  static const _ink = Color(0xFF160A1C);
  static const _dust = Color(0xFF2E1B36);
  static const _ember = Color(0xFFFF7A29);
  static const _emberDeep = Color(0xFFD94F16);
  static const _flame = Color(0xFFFF2E7E);
  static const _flameDeep = Color(0xFF9B1B5E);
  static const _lavender = Color(0xFFB78CFF);
  static const _violet = Color(0xFF5B2E91);
  static const _pollen = Color(0xFFFFE9A8);
  static const _amber = Color(0xFFFFB347);
  static const _blush = Color(0xFFFF5C8A);

  // Deterministic hash noise in [0, 1): lattice-scrambled so adjacent inputs
  // decorrelate. Any other constant set gives a visibly different mandala.
  static double _n(int i) {
    var x = (i * 374761393 + 668265263) & 0xFFFFFFFF;
    x = ((x ^ (x >> 13)) * 1274126177) & 0xFFFFFFFF;
    x ^= x >> 16;
    return x / 4294967296.0;
  }

  static double _n2(int i, int j) => _n(i * 971 + j * 31337);

  static Offset _p(Offset c, double a, double r) =>
      Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.shortestSide * 0.485;
    final rot = -math.pi / 2;
    final fill = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(20260831);

    // 1. Near-black plum field with a soft violet haze behind the bloom.
    canvas.drawRect(Offset.zero & size, Paint()..color = _ink);
    canvas.drawCircle(
      c,
      R * 1.06,
      Paint()
        ..shader = ui.Gradient.radial(c, R * 1.06, const [
          Color(0xFF2B1540),
          Color(0xFF1A0D26),
          Color(0x00160A1C),
        ], const [0.0, 0.55, 1.0]),
    );

    // 2. Star dust: 60 dim pinpricks scattered outside the bloom.
    for (var i = 0; i < 60; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final rr = R * (1.04 + 0.75 * rng.nextDouble());
      final p = _p(c, a, rr);
      if (p.dx < 0 || p.dx > size.width || p.dy < 0 || p.dy > size.height) {
        continue;
      }
      fill.color = _dust.withOpacity(0.25 + 0.45 * rng.nextDouble());
      canvas.drawCircle(p, 0.7 + rng.nextDouble() * 1.6, fill);
    }

    // 3. 21 concentric guide rings, unevenly spaced, many broken — their
    // phase offsets come from the hash noise, so every gap lands differently.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _dust.withOpacity(0.55);
    for (var i = 0; i < 21; i++) {
      final rr = R * (0.10 + 0.88 * math.pow(i / 20, 1.25));
      ringPaint.strokeWidth = 0.7 + _n(i) * 0.9;
      if (i % 3 == 2) {
        final start = rot + _n(i + 500) * 2 * math.pi;
        canvas.drawArc(Rect.fromCircle(center: c, radius: rr), start,
            1.1 + _n(i + 900) * 3.6, false, ringPaint);
      } else {
        canvas.drawCircle(c, rr, ringPaint);
      }
    }

    // 4. 72 radial filaments from hub to rim; a deterministic ~35% are dim.
    for (var i = 0; i < 72; i++) {
      final a = rot + i * 2 * math.pi / 72;
      final faint = _n(i + 2000) < 0.35;
      canvas.drawLine(
        _p(c, a, R * 0.085),
        _p(c, a, R * 0.985),
        Paint()
          ..strokeWidth = faint ? 0.7 : 1.0
          ..color = faint
              ? _dust.withOpacity(0.30)
              : _violet.withOpacity(0.50),
      );
    }

    // 5. Outer flame fronds: 22 quadratic flames leaning alternately, each
    // filled toward deep crimson, rimmed hot pink, with a spine and a
    // spiral of 12 shrinking ember tips along its length.
    for (var i = 0; i < 22; i++) {
      final a = rot + i * 2 * math.pi / 22 + _n(i + 300) * 0.06;
      final lean = (i.isEven ? 1 : -1) * (0.30 + _n(i + 310) * 0.16);
      final inner = R * (0.62 + _n(i + 320) * 0.05);
      final tipR = R * (0.965 + _n(i + 330) * 0.05);
      final wHalf = R * (0.045 + _n(i + 340) * 0.03);
      final base = _p(c, a, inner);
      final tip = _p(c, a + lean, tipR);
      final mid = _p(c, a + lean * 0.5, (inner + tipR) * 0.52);
      final perp = a + math.pi / 2;

      final flamePath = Path()
        ..moveTo(base.dx + wHalf * math.cos(perp),
            base.dy + wHalf * math.sin(perp))
        ..quadraticBezierTo(
            mid.dx + wHalf * 1.9 * math.cos(perp + lean),
            mid.dy + wHalf * 1.9 * math.sin(perp + lean),
            tip.dx,
            tip.dy)
        ..quadraticBezierTo(
            mid.dx - wHalf * 1.9 * math.cos(perp + lean),
            mid.dy - wHalf * 1.9 * math.sin(perp + lean),
            base.dx - wHalf * math.cos(perp),
            base.dy - wHalf * math.sin(perp))
        ..close();
      canvas.drawPath(
        flamePath,
        Paint()
          ..shader = ui.Gradient.linear(base, tip, [
            _flameDeep.withOpacity(0.85),
            _blush.withOpacity(0.90),
            _amber.withOpacity(0.95),
          ], const [0.0, 0.6, 1.0]),
      );
      canvas.drawPath(
        flamePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = _flame.withOpacity(0.55),
      );
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..strokeWidth = 0.8
          ..color = _pollen.withOpacity(0.35),
      );

      // Ember tips march along the flame with noise-driven radial jitter.
      for (var j = 0; j < 12; j++) {
        final f = (j + 1) / 13;
        final rr = inner + (tipR - inner) * f;
        final jitter = (_n2(i, j) - 0.5) * 0.05;
        final r = 2.6 * (1 - f * 0.55) * (0.75 + 0.5 * _n2(i + 77, j));
        fill.color = Color.lerp(_amber, _pollen, f)!
            .withOpacity((1 - f * 0.35).clamp(0.0, 1.0));
        canvas.drawCircle(_p(c, a + lean * f + jitter, rr), r, fill);
      }
    }

    // 6. Petal lattice: 15 petals per layer. The two middle layers rotate by
    // a golden-angle step plus noise, so their petals deliberately do NOT
    // sit halfway between the outer layer's — most guessed mandalas align.
    const golden = 2.39996322972865332;
    for (var layer = 4; layer >= 0; layer--) {
      final lr = R * [0.70, 0.565, 0.435, 0.315, 0.21][layer];
      final twist = layer == 3
          ? golden + _n(layer + 40) * 0.5
          : layer == 2
              ? 2 * golden + _n(layer + 50) * 0.5
              : _n(layer + 60) * 0.35;
      final colA = Color.lerp(_flame, _ember, layer / 4)!;
      final colB = Color.lerp(_violet, _lavender, layer / 4)!;

      for (var i = 0; i < 15; i++) {
        final a = rot + i * 2 * math.pi / 15 + twist;
        final inner = lr * 0.55;
        final tipR = lr * (1.10 + _n2(layer, i) * 0.10);
        final wHalf = lr * (0.150 + _n2(i, layer + 9) * 0.06);
        final base = _p(c, a, inner);
        final tip = _p(c, a, tipR);
        final cpL = _p(c, a - 0.22, lr * 0.92);
        final cpR = _p(c, a + 0.22, lr * 0.92);
        final c1 = Offset(cpL.dx + wHalf * math.cos(a - math.pi / 2),
            cpL.dy + wHalf * math.sin(a - math.pi / 2));
        final c2 = Offset(cpR.dx - wHalf * math.cos(a - math.pi / 2),
            cpR.dy - wHalf * math.sin(a - math.pi / 2));

        final petal = Path()
          ..moveTo(base.dx, base.dy)
          ..cubicTo(c1.dx, c1.dy, tip.dx - wHalf * 0.4 * math.cos(a),
              tip.dy - wHalf * 0.4 * math.sin(a), tip.dx, tip.dy)
          ..cubicTo(tip.dx - wHalf * 0.4 * math.cos(a + math.pi),
              tip.dy - wHalf * 0.4 * math.sin(a + math.pi), c2.dx, c2.dy,
              base.dx, base.dy)
          ..close();
        canvas.drawPath(
          petal,
          Paint()
            ..shader = ui.Gradient.linear(base, tip, [
              colB.withOpacity(0.85),
              colA.withOpacity(0.92),
            ]),
        );
        canvas.drawPath(
          petal,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Color.lerp(colA, _pollen, 0.35)!.withOpacity(0.8),
        );

        // Inner veins: 28 dots shrinking along the midline with sinusoidal
        // spacing jitter — organic, and impossible to enumerate in prose.
        for (var j = 0; j < 28; j++) {
          final f = (j + 1) / 29;
          final rr = inner + (tipR * 0.92 - inner) * f;
          final r = 1.7 * (1 - f * 0.62) * (0.8 + 0.4 * _n2(j, layer));
          if (r <= 0.05) continue;
          final off = math.sin(f * 21 + layer * 2.2 + i * 0.7) * 0.012;
          fill.color = _pollen.withOpacity((0.9 - f * 0.45).clamp(0.0, 1.0));
          canvas.drawCircle(_p(c, a + off, rr), r, fill);
        }
      }
    }

    // 7. Seed head: 180 seeds on a phyllotactic spiral. Heading is golden
    // angle, but radius uses sqrt(i * 1.17) — a specific off-true packing
    // that reads as organic and never reproduces from a guessed formula.
    final headR = R * 0.19;
    for (var i = 0; i < 180; i++) {
      final a = i * golden + rot;
      final rr = headR * math.sqrt(i * 1.17) / math.sqrt(180 * 1.17);
      final f = i / 180;
      fill.color = Color.lerp(_pollen, _ember, f)!
          .withOpacity(0.95 - f * 0.25);
      canvas.drawCircle(_p(c, a, rr), 2.2 - f * 0.9, fill);
    }

    // 8. Ember core: five rings of additive circles, counts 7/9/11/13/15,
    // radii walking the golden-ratio conjugate down toward the hub, each
    // ring jittered by noise and counter-rotated from the last.
    for (var k = 0; k < 5; k++) {
      final count = 7 + 2 * k;
      final rr = R * 0.115 * math.pow(0.618, k);
      final phase = rot + (k.isOdd ? math.pi / count : 0.0) + _n(k + 88) * 0.2;
      for (var i = 0; i < count; i++) {
        final a = phase + i * 2 * math.pi / count + (_n2(k, i) - 0.5) * 0.05;
        final r = (7.0 - k) * (0.9 + 0.3 * _n2(i, k + 5));
        final p = _p(c, a, rr * (0.92 + 0.16 * _n2(k + 3, i)));
        canvas.drawCircle(
          p,
          r * 2.4,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = _emberDeep.withOpacity(0.10),
        );
        fill.color = Color.lerp(_ember, _pollen, k / 4)!;
        canvas.drawCircle(p, r, fill);
      }
    }

    // Hub: one hot heart with a soft additive glow.
    canvas.drawCircle(
      c,
      14,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _ember.withOpacity(0.35),
    );
    canvas.drawCircle(c, 5.5, Paint()..color = _pollen);

    // 9. Drifting spores: 130 hash-placed motes, warm near the core fading
    // to cool violet at the rim, with a bright white pinprick in the big ones.
    for (var i = 0; i < 130; i++) {
      final a = _n(i + 4000) * 2 * math.pi;
      final rr = R * (0.10 + 0.92 * _n(i + 5000));
      final f = rr / R;
      final r = 0.6 + 2.0 * _n(i + 6000);
      fill.color = Color.lerp(_amber, _lavender, f)!
          .withOpacity(0.20 + 0.55 * _n(i + 7000));
      canvas.drawCircle(_p(c, a, rr), r, fill);
      if (r > 1.9 && _n(i + 8000) > 0.5) {
        canvas.drawCircle(
            _p(c, a, rr), 0.8, Paint()..color = Colors.white.withOpacity(0.8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant EmberbloomPainter oldDelegate) => false;
}
