// name: Nox Brew
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
                _header(), const SizedBox(height: 48),
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
