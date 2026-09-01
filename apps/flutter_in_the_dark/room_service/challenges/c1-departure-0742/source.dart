// name: C1 - Departure 07:42
import 'package:flutter/material.dart';

void main() {
  runApp(const DepartureApp());
}

class DepartureApp extends StatelessWidget {
  const DepartureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DepartureScreen(),
    );
  }
}

class DepartureScreen extends StatelessWidget {
  const DepartureScreen({super.key});

  // Two-tone palette: ink background, bone text, one amber accent.
  static const Color ink = Color(0xFF0E0F13);
  static const Color bone = Color(0xFFF2EFE6);
  static const Color amber = Color(0xFFFFB300);
  static const Color dim = Color(0xFF6B6E78);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top eyebrow row: small-caps labels at the far edges.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label('NORTHBOUND', dim),
                  _label('TRACK 4', amber),
                ],
              ),
              const SizedBox(height: 28),

              // City name: heavy, wide-tracked, uppercase.
              const Text(
                'STOCKHOLM',
                style: TextStyle(
                  color: bone,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              _label('CENTRAL STATION', dim),

              const Spacer(),

              // The big number — the scoring magnet.
              const Text(
                '07:42',
                style: TextStyle(
                  color: bone,
                  fontSize: 168,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -4,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              // Thin amber rule, full width.
              Container(width: double.infinity, height: 2, color: amber),
              const SizedBox(height: 24),

              // Metadata strip: three spaced columns of label-over-value.
              const Row(
                children: [
                  _Meta(label: 'PLATFORM', value: '4'),
                  SizedBox(width: 48),
                  _Meta(label: 'CARS', value: '6'),
                  SizedBox(width: 48),
                  _Meta(label: 'ON TIME', value: '+0 MIN', accent: true),
                ],
              ),

              const Spacer(),

              // Bottom status strip: a bordered badge on the left, dim note right.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: amber, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _label('BOARDING', amber),
                  ),
                  _label('GATE CLOSES 07:37', dim),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small-caps micro-label: the recurring typographic unit.
  static Widget _label(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.5,
        height: 1.0,
      ),
    );
  }
}

/// One metadata column: a dim label stacked over a bone value.
class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: DepartureScreen.dim,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: accent ? DepartureScreen.amber : DepartureScreen.bone,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
