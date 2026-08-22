import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class Finals extends StatelessWidget {
  static const path = "/finals";

  const Finals({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Hey, I'm loading here!"),
        ),
        body: const Center(child: Loader()),
      ),
    );
  }
}

class Loader extends HookWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    const duration = Duration(milliseconds: 700);
    final animationController = useAnimationController(
      duration: duration,
    );

    final curved = useMemoized(
      () => CurvedAnimation(
        parent: animationController,
        curve: Curves.easeInOut,
      ),
      [animationController],
    );
    useEffect(
      () {
        animationController.repeat(reverse: true);
        return null;
      },
      [animationController],
    );

    final animation = useAnimation(curved);
    return Center(
      child: RepaintBoundary(
        child: SizedBox(
          height: size * 2,
          width: size,
          child: CustomPaint(
            painter:
                _BallsPainter(color: const Color(0xFF038069), scale: animation),
          ),
        ),
      ),
    );
  }
}

class _BallsPainter extends CustomPainter {
  final Color color;
  final double scale;
  late final Paint _paint = Paint()..color = color;
  final scaleTween = Tween<double>(begin: 1, end: 0.3);

  _BallsPainter({
    required this.color,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final xCenter = size.width / 2;
    final yCenter = size.height / 4;
    canvas.drawCircle(
      Offset(xCenter, yCenter),
      radius * scaleTween.transform(scale),
      _paint,
    );
    canvas.drawCircle(
      Offset(xCenter, yCenter * 3),
      radius * scaleTween.transform(1 - scale),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_BallsPainter oldDelegate) =>
      color != oldDelegate.color || scale != oldDelegate.scale;
}
