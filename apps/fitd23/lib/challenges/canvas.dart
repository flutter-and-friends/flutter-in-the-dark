import 'package:flutter/material.dart';

class CanvasHouse extends StatelessWidget {
  static const path = "/canvasHouse";

  const CanvasHouse({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black45,
        title: const Text("Draw your dream house"),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: CustomPaint(
              painter: HousePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class HousePainter extends CustomPainter {
  final Paint _paint = Paint()
    ..color = Colors.black
    ..strokeWidth = 2;

  final Paint _sunPaint = Paint()
    ..color = Colors.orange
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    Rect myRect = const Offset(10.0, 20.0) & const Size(60.0, 80.0);
    canvas.drawRect(myRect, _paint);
    canvas.drawLine(const Offset(0.0, 20.0), const Offset(80.0, 20.0), _paint);
    canvas.drawLine(
        const Offset(40.0, -20.0), const Offset(80.0, 20.0), _paint);
    canvas.drawLine(const Offset(40.0, -20.0), const Offset(0.0, 20.0), _paint);
    canvas.drawCircle(const Offset(90.0, -80.0), 22, _sunPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
