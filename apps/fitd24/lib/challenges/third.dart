import 'dart:ui';

import 'package:flutter/material.dart';

class Third extends StatelessWidget {
  const Third({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            const FrostedBackground(
              image: dash,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 100),
                    const CircleAvatar(
                      radius: 75,
                      backgroundColor: Colors.black45,
                      child: Image(image: dash),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dash',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BottomSheet(
                onClosing: () {},
                backgroundColor: Colors.black12,
                builder: (context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          'Incoming call',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Dash',
                          style: theme.textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'mobile',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alarm),
                              const SizedBox(height: 6),
                              Text(
                                'Remind me',
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(height: 32),
                              const CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                radius: 36,
                                child: Icon(Icons.phone_missed),
                              ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.message),
                              const SizedBox(height: 6),
                              Text(
                                'Message',
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(height: 32),
                              const CircleAvatar(
                                backgroundColor: Colors.green,
                                radius: 36,
                                child: Icon(Icons.phone),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 75),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const dash = AssetImage('assets/photos/dash.png');

class FrostedBackground extends StatelessWidget {
  final AssetImage image;

  const FrostedBackground({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image(
            image: image,
            fit: BoxFit.cover,
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
  }
}
