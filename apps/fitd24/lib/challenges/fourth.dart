import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

class Fourth extends StatelessWidget {
  const Fourth({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: Stack(
          children: [
            const Positioned.fill(child: FrostedBackground()),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(42),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 350),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(42),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Image(image: dash),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Dash beats',
                        style: theme.textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The Stateful Shenanigans',
                        style: theme.textTheme.labelMedium!
                            .copyWith(color: Colors.white54),
                      ),
                      Slider(
                        onChanged: (_) {},
                        value: 100 / 180,
                      ),
                      const Row(
                        children: [
                          Text('1:40'),
                          Spacer(),
                          Text('3:00'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fast_rewind, size: 36),
                          SizedBox(width: 16),
                          CircleAvatar(
                            backgroundColor: Colors.white12,
                            radius: 36,
                            child: Icon(Icons.pause, size: 42),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.fast_forward, size: 36),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.volume_down),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: const LinearProgressIndicator(value: 0.25),
                          ),
                        ],
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.favorite_border, color: Colors.white30),
                          Icon(Icons.share, color: Colors.white30),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
