// name: Lunar Landing Console
import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  runApp(const ConsoleApp());
}

class ConsoleApp extends StatelessWidget {
  const ConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const ConsoleScreen(),
    );
  }
}

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Column(
              children: [
                _Header(t: t),
                const Divider(height: 1, color: Color(0xFF2A3350)),
                Expanded(flex: 6, child: _TelemetryPane(t: t)),
                const Divider(height: 1, color: Color(0xFF2A3350)),
                const Expanded(flex: 4, child: _SystemsPane()),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final metSeconds = (t * 420).floor();
    final mm = (metSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (metSeconds % 60).toString().padLeft(2, '0');
    final blink = (t * 24).floor().isEven;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF5252),
              boxShadow: [
                if (blink)
                  const BoxShadow(color: Color(0xFFFF5252), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'ARTEMIS-7  //  LUNAR DESCENT',
            style: TextStyle(
              color: Color(0xFFE8ECF7),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'MET',
                style: TextStyle(
                  color: Color(0xFF8A93AD),
                  fontSize: 10,
                  letterSpacing: 3,
                ),
              ),
              Text(
                'T+$mm:$ss',
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontSize: 20,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- telemetry

class _TelemetryPane extends StatelessWidget {
  const _TelemetryPane({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final gaugeSize =
            math.min(c.maxHeight, c.maxWidth / 2 - 32).clamp(0.0, 220.0);
        final altitudeKm = 18.4 - t * 6.2;
        final fuelPct = (62.0 - t * 11.0).clamp(0.0, 100.0);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Readout(
                      label: 'ALTITUDE',
                      value: '18.4',
                      unit: 'km',
                    ),
                    const SizedBox(height: 12),
                    const _Readout(
                      label: 'VERT SPEED',
                      value: '-12.6',
                      unit: 'm/s',
                    ),
                    const SizedBox(height: 12),
                    const _Readout(
                      label: 'HOR SPEED',
                      value: '4.1',
                      unit: 'm/s',
                    ),
                    const SizedBox(height: 12),
                    _Readout(
                      label: 'THROTTLE',
                      value: '${(fuelPct / 100 * 78).round()}',
                      unit: '%',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: gaugeSize,
                height: gaugeSize,
                child: CustomPaint(
                  painter: _RadarPainter(t, descentFraction: t),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Readout(
                      label: 'FUEL',
                      value: fuelPct.toStringAsFixed(1),
                      unit: '%',
                      valueColor: fuelPct < 30
                          ? const Color(0xFFFF5252)
                          : const Color(0xFF64FFB4),
                    ),
                    const SizedBox(height: 12),
                    _Readout(
                      label: 'CABIN O2',
                      value: '${(21.0 + math.sin(t * math.pi * 8) * 0.3).toStringAsFixed(1)}',
                      unit: '%',
                    ),
                    const SizedBox(height: 12),
                    _Readout(
                      label: 'PITCH',
                      value: '${(math.sin(t * math.pi * 2) * 2.4).toStringAsFixed(1)}',
                      unit: 'deg',
                    ),
                    const SizedBox(height: 12),
                    _Readout(
                      label: 'ALT TGT',
                      value: (altitudeKm - 6.2).clamp(0, 99).toStringAsFixed(1),
                      unit: 'km',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor = const Color(0xFF64FFB4),
  });

  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF11162A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3350)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A93AD),
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            unit,
            style: const TextStyle(color: Color(0xFF8A93AD), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, {required this.descentFraction});

  final double t;
  final double descentFraction;

  static const _amber = Color(0xFFFFC857);
  static const _dim = Color(0xFF3A4568);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final paint = Paint()..color = _dim;

    // Radar rings and crosshair.
    for (final f in [1.0, 0.66, 0.33]) {
      canvas.drawCircle(c, r * f, paint..style = PaintingStyle.stroke);
    }
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);

    // Rotating sweep with fading trail wedges.
    final sweepAngle = t * math.pi * 2;
    for (var i = 0; i < 24; i++) {
      final a = sweepAngle - i * 0.045;
      final p = Paint()
        ..color = _amber.withOpacity(0.16 * (1 - i / 24))
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a - 0.045,
        0.045,
        true,
        p,
      );
    }
    canvas.drawLine(
      c,
      Offset(c.dx + r * math.cos(sweepAngle), c.dy + r * math.sin(sweepAngle)),
      Paint()
        ..color = _amber
        ..strokeWidth = 2,
    );

    // Blips that flash when the sweep passes them.
    const blips = [(0.35, 0.8), (0.6, 2.4), (0.8, 4.2), (0.5, 5.5)];
    for (final (radiusF, angle) in blips) {
      final diff = (sweepAngle - angle) % (math.pi * 2);
      final glow = (1 - diff / (math.pi * 2)).clamp(0.0, 1.0);
      final pos = Offset(
        c.dx + r * radiusF * math.cos(angle),
        c.dy + r * radiusF * math.sin(angle),
      );
      canvas.drawCircle(
        pos,
        3 + glow * 3,
        Paint()..color = Colors.white.withOpacity(0.25 + glow * 0.75),
      );
    }

    // Descent marker: a small triangle sinking toward the center.
    final landerR = r * (1 - descentFraction * 0.85);
    final lp = Offset(c.dx + landerR * 0.35, c.dy - landerR * 0.55);
    final tri = Path()
      ..moveTo(lp.dx, lp.dy - 7)
      ..lineTo(lp.dx - 6, lp.dy + 5)
      ..lineTo(lp.dx + 6, lp.dy + 5)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFF64FFB4));
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

// ---------------------------------------------------------------- systems

class _SystemsPane extends StatelessWidget {
  const _SystemsPane();

  static const _systems = [
    ('GUIDANCE', true),
    ('COMMS UPLINK', true),
    ('RCS THRUSTERS', true),
    ('FUEL CELL', false),
    ('LIDAR SCAN', true),
    ('CO2 SCRUBBER', false),
    ('MAIN ENGINE', true),
    ('LANDING RADAR', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYSTEMS STATUS',
            style: TextStyle(
              color: Color(0xFF8A93AD),
              fontSize: 11,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final (name, nominal) in _systems)
                  _StatusChip(label: name, nominal: nominal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.nominal});

  final String label;
  final bool nominal;

  @override
  Widget build(BuildContext context) {
    final color =
        nominal ? const Color(0xFF64FFB4) : const Color(0xFFFFC857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF11162A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
