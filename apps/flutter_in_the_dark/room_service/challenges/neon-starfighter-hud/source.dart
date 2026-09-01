// name: Neon Starfighter HUD
import 'dart:math' as math;

import 'package:flutter/material.dart';

const _bg = Color(0xFF050A14), _panel = Color(0xFF0A1424), _cyan = Color(0xFF2DE2E6),
    _green = Color(0xFF39FF88), _amber = Color(0xFFFFB000), _magenta = Color(0xFFFF3EA5),
    _red = Color(0xFFFF4655), _dim = Color(0xFF5F7A99);

TextStyle _label(double size, [Color color = _dim]) =>
    TextStyle(color: color, fontSize: size, letterSpacing: 3, fontWeight: FontWeight.w600);
TextStyle _digits(double size, Color color) =>
    TextStyle(color: color, fontSize: size, letterSpacing: 2, fontWeight: FontWeight.bold);

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const HudScreen(),
    ));

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});
  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _score(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label, style: _label(11)), Text(value, style: _digits(26, color))],
      );

  Widget _bar(String label, double frac, Color color) {
    final lit = (frac * 20).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: _label(11))),
        Expanded(
          child: Row(children: [
            for (var i = 0; i < 20; i++)
              Expanded(
                child: Container(
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: i < lit ? color : _panel,
                    border: Border.all(color: color.withOpacity(i < lit ? 1.0 : 0.35)),
                  ),
                ),
              ),
          ]),
        ),
        SizedBox(
          width: 48,
          child: Text('${(frac * 100).round()}', style: _digits(15, color), textAlign: TextAlign.right),
        ),
      ]),
    );
  }

  Widget _header(bool blinkOn) => Column(children: [
        Row(children: [
          Text('NEON STARFIGHTER', style: _label(18, _cyan).copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Opacity(opacity: blinkOn ? 1.0 : 0.12, child: Text('INSERT COIN', style: _label(13, _amber))),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 2,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_cyan, Colors.transparent, _magenta])),
        ),
      ]);

  Widget _levelRow() => Row(children: [
        Text('LEVEL 07', style: _digits(30, Colors.white)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(border: Border.all(color: _dim), borderRadius: BorderRadius.circular(3)),
          child: Text('SECTOR 4', style: _label(11, _cyan)),
        ),
        const Spacer(),
        Transform.rotate(
          angle: -0.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _magenta.withOpacity(0.14),
              border: Border.all(color: _magenta, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('COMBO x3', style: _digits(16, _magenta).copyWith(letterSpacing: 3)),
          ),
        ),
      ]);

  Widget _statPanel() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('LIVES', style: _label(11)),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 22, height: 24, child: CustomPaint(painter: _ShipPainter())),
            ),
        ]),
        const SizedBox(height: 14),
        Text('BOMBS', style: _label(11)),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 12, height: 12,
              margin: const EdgeInsets.only(right: 8),
              transform: Matrix4.rotationZ(math.pi / 4),
              decoration: BoxDecoration(color: _amber, border: Border.all(color: _amber)),
            ),
        ]),
        const SizedBox(height: 14),
        Text('WEAPON', style: _label(11)),
        Text('SPREAD LV3', style: _digits(15, _cyan)),
        const Spacer(),
        Text('TIME', style: _label(11)),
        Text('45', style: _digits(30, Colors.white)),
      ]);

  Widget _lowerPanel(double t) => Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: _panel,
                border: Border.all(color: _cyan.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(8),
              child: CustomPaint(painter: _RadarPainter(t)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(flex: 4, child: _statPanel()),
        ]),
      );

  Widget _waveRow() => Row(children: [
        Text('WAVE 3/8', style: _label(11, Colors.white)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 8,
            color: _panel,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: 3 / 8, child: Container(color: _magenta)),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final blinkOn = (t * 2).floor() % 2 == 0;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _header(blinkOn),
                  const SizedBox(height: 14),
                  Row(children: [
                    _score('SCORE', '024500', _green),
                    const SizedBox(width: 36),
                    _score('HI-SCORE', '138750', _cyan),
                    const Spacer(),
                    _score('CREDIT', '02', _dim),
                  ]),
                  const SizedBox(height: 12),
                  _levelRow(),
                  const SizedBox(height: 14),
                  _bar('SHIELD', 0.76, _green),
                  _bar('ENERGY', 0.42, _amber),
                  _bar('BOSS', 0.18, _red),
                  const SizedBox(height: 10),
                  _lowerPanel(t),
                  const SizedBox(height: 12),
                  _waveRow(),
                  const SizedBox(height: 8),
                  Center(child: Text('PLAYER 1 - READY', style: _label(10, _dim))),
                ]),
              );
            },
          ),
        ),
      );
}

class _ShipPainter extends CustomPainter {
  const _ShipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hull = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h)
      ..lineTo(w / 2, h * 0.72)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hull, Paint()..color = _cyan);
    canvas.drawCircle(Offset(w / 2, h * 0.55), w * 0.12, Paint()..color = _bg);
  }

  @override
  bool shouldRepaint(_ShipPainter oldDelegate) => false;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.phase);

  final double phase;

  static final List<Offset> _blips = () {
    final rng = math.Random(3);
    return [
      for (var i = 0; i < 5; i++)
        Offset.fromDirection(rng.nextDouble() * 2 * math.pi, 0.2 + rng.nextDouble() * 0.72),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _green.withOpacity(0.45);

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF071018));
    for (final f in [1.0, 0.66, 0.33]) {
      canvas.drawCircle(center, radius * f, ring);
    }
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), ring);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), ring);

    // Rotating sweep with a short fading trail.
    final sweepAngle = 2 * math.pi * phase;
    for (var k = 0; k < 3; k++) {
      final a = sweepAngle - k * 0.14;
      canvas.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * radius,
        Paint()
          ..strokeWidth = 2
          ..color = _green.withOpacity(0.9 - k * 0.3),
      );
    }

    for (final b in _blips) {
      canvas.drawCircle(center + b * radius, 3, Paint()..color = _red);
    }
    canvas.drawCircle(center, 2.5, Paint()..color = _green);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => oldDelegate.phase != phase;
}
