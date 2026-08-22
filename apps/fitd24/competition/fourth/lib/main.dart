import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}

const dash = AssetImage('assets/photos/dash.png');

class FrostedBackground extends StatefulWidget {
  const FrostedBackground({super.key});

  @override
  State<FrostedBackground> createState() => _FrostedBackgroundState();
}

class _FrostedBackgroundState extends State<FrostedBackground> {
  double top = 0.0;
  double left = 0.0;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        moveRandom(
          height: 300,
          width: 300,
          imageSize: 300 / 1.5,
        );
      },
    );
    super.initState();
  }

  final random = Random();

  void moveRandom({
    required double width,
    required double height,
    required double imageSize,
  }) {
    final x = random.nextDouble() * (width - imageSize);
    final y = random.nextDouble() * (height - imageSize / 2);
    setState(() {
      left = x;
      top = y;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      var imageSize = min(constraints.maxWidth, constraints.maxHeight) / 1.5;

      return Stack(
        children: [
          AnimatedPositioned(
            key: const ValueKey('animation'),
            curve: Curves.easeInOut,
            duration: const Duration(seconds: 3),
            left: left,
            top: top,
            onEnd: () {
              moveRandom(
                imageSize: imageSize,
                width: constraints.maxWidth,
                height: constraints.maxWidth,
              );
            },
            child: Image(
              image: dash,
              height: imageSize,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 450,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
