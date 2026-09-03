// name: C4 - Nox Brew
import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';

void main() => runApp(const NoxApp());

const Color kBg = Color(0xFF0C0A10);
const Color kCard = Color(0xFF17131E);
const Color kCardBorder = Color(0xFF2C2438);
const Color kAmber = Color(0xFFE8A33D);
const Color kTextHi = Color(0xFFF4EEE3);
const Color kTextLo = Color(0xFF9C93A8);

class NoxApp extends StatelessWidget {
  const NoxApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const NoxPage(),
      );
}

class NoxPage extends StatelessWidget {
  const NoxPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _header(), const SizedBox(height: 30),
                const _HeroCup(), const SizedBox(height: 30),
                _eyebrow(), const SizedBox(height: 16),
                const Text(
                  'Coffee for the\nquiet hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kTextHi,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Small-batch beans, roasted after dark and delivered before you wake. Brewed slow, sipped slower.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextLo, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 30),
                _cta(), const SizedBox(height: 44),
                Row(
                  children: const [
                    Expanded(child: NoxFeatureCard(glyph: _Glyph.moon, label: 'Roasted\nat night')),
                    SizedBox(width: 12),
                    Expanded(child: NoxFeatureCard(glyph: _Glyph.drop, label: 'Single\norigin')),
                    SizedBox(width: 12),
                    Expanded(child: NoxFeatureCard(glyph: _Glyph.box, label: 'Weekly\ndelivery')),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  '© 2026 Nox Brew Co. — brewed in the dark',
                  style: TextStyle(color: kTextLo, fontSize: 11, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: kAmber, borderRadius: BorderRadius.circular(9)),
              alignment: Alignment.center,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'NOX BREW',
              style: TextStyle(color: kTextHi, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2.0),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: kCardBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Sign in', style: TextStyle(color: kTextLo, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _eyebrow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kCardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'MIDNIGHT ROAST CLUB',
        style: TextStyle(color: kAmber, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 3.0),
      ),
    );
  }

  Widget _cta() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: kAmber,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Color(0x59E8A33D), blurRadius: 24)],
        ),
        alignment: Alignment.center,
        child: const Text(
          'Start your ritual',
          style: TextStyle(color: Color(0xFF1A1206), fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
}

/// The hero cup with gently wobbling steam. Owns the controller so the rest
/// of the page stays static; only this 150x168 region repaints per tick.
class _HeroCup extends StatefulWidget {
  const _HeroCup();

  @override
  State<_HeroCup> createState() => _HeroCupState();
}

class _HeroCupState extends State<_HeroCup> with SingleTickerProviderStateMixin {
  late final AnimationController _steam = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _steam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 168,
        child: CustomPaint(painter: _CupPainter(_steam)),
      );
}

enum _Glyph { moon, drop, box }

class NoxFeatureCard extends StatelessWidget {
  final _Glyph glyph;
  final String label;
  const NoxFeatureCard({super.key, required this.glyph, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kCardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(painter: _GlyphPainter(glyph, kAmber)),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kTextHi, fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final _Glyph glyph;
  final Color color;
  _GlyphPainter(this.glyph, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final c = Offset(size.width / 2, size.height / 2);
    switch (glyph) {
      case _Glyph.moon:
        canvas.drawCircle(c, size.width / 2, paint);
        canvas.drawCircle(
          c.translate(size.width * 0.22, -size.height * 0.18),
          size.width * 0.38,
          Paint()..color = kCard,
        );
      case _Glyph.drop:
        canvas.drawCircle(Offset(c.dx, size.height * 0.62), size.width * 0.3, paint);
        final path = Path()
          ..moveTo(c.dx, 0)
          ..lineTo(c.dx - size.width * 0.3, size.height * 0.62)
          ..lineTo(c.dx + size.width * 0.3, size.height * 0.62)
          ..close();
        canvas.drawPath(path, paint);
      case _Glyph.box:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: size.width * 0.78, height: size.height * 0.78),
            const Radius.circular(4),
          ),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => false;
}

class _CupPainter extends CustomPainter {
  final Animation<double> steam;
  _CupPainter(this.steam) : super(repaint: steam);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final amber = Paint()..color = kAmber;

    // One tight glow behind the cup, echoing the CTA shadow.
    final glowCenter = Offset(w * 0.5, h * 0.60);
    canvas.drawCircle(
      glowCenter,
      w * 0.60,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x24E8A33D), Color(0x00E8A33D)],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: w * 0.60)),
    );

    // Steam: three tall, gentle S-curves rising from the coffee, drifting
    // side to side as whole lines (the base sways with the tip — no worm
    // wriggle). Integer cycles per controller loop keep the 6s repeat
    // seamless; phases and amplitudes differ so the wisps never move in
    // lockstep.
    final t = steam.value;
    final steamPaint = Paint()
      ..color = kAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.026
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_wisp(w * 0.40, h * 0.30, h * 0.10, w * 0.030, t, 1, 0.00, w * 0.028, w * 0.010), steamPaint);
    canvas.drawPath(_wisp(w * 0.50, h * 0.31, h * 0.04, w * 0.030, t, 2, 0.40, w * 0.024, w * 0.012), steamPaint);
    canvas.drawPath(_wisp(w * 0.60, h * 0.30, h * 0.10, w * 0.030, t, 1, 0.75, w * 0.026, w * 0.010), steamPaint);

    // Saucer: a flat pill the cup sits on.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.845), width: w * 0.80, height: h * 0.045),
        Radius.circular(h * 0.0225),
      ),
      amber,
    );

    // Cup body: flat top, generously rounded bottom — a mug silhouette.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.24, h * 0.34, w * 0.76, h * 0.82),
        topLeft: Radius.circular(h * 0.03),
        topRight: Radius.circular(h * 0.03),
        bottomLeft: Radius.circular(h * 0.16),
        bottomRight: Radius.circular(h * 0.16),
      ),
      amber,
    );

    // Coffee: a dark ellipse inset just below the rim.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.29, h * 0.355, w * 0.42, h * 0.055),
      Paint()..color = kBg,
    );

    // Handle: the right half of an oval, stroked.
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.78, h * 0.58), width: w * 0.20, height: h * 0.24),
      -pi / 2,
      pi,
      false,
      Paint()
        ..color = kAmber
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.034
        ..strokeCap = StrokeCap.round,
    );
  }

  // dx(p) is the lateral offset at relative height p (0 = base, 1 = tip).
  // The dominant term is a uniform drift — the whole line, base included,
  // translates with sin(theta). A much smaller p-scaled wave rides on top so
  // the tip exaggerates the sway slightly and the line never reads rigid.
  Path _wisp(
    double x,
    double yBottom,
    double yTop,
    double sway,
    double t,
    int cycles,
    double phase,
    double drift,
    double wave,
  ) {
    final yMid = (yBottom + yTop) / 2;
    final theta = 2 * pi * (cycles * t + phase);
    double dx(double p) => drift * sin(theta) + wave * p * sin(theta + 2.0 * p);
    return Path()
      ..moveTo(x + dx(0), yBottom)
      ..cubicTo(
        x - sway + dx(0.17),
        yBottom - (yBottom - yMid) * 0.55,
        x + sway + dx(0.33),
        yMid + (yBottom - yMid) * 0.45,
        x + dx(0.5),
        yMid,
      )
      ..cubicTo(
        x - sway + dx(0.67),
        yMid - (yMid - yTop) * 0.55,
        x + sway + dx(0.83),
        yTop + (yMid - yTop) * 0.45,
        x + dx(1),
        yTop,
      );
  }

  @override
  bool shouldRepaint(_CupPainter oldDelegate) => false;
}
