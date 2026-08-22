import 'dart:async';

import 'package:flutter/material.dart';

class First extends StatelessWidget {
  const First({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [innerColor, outerColor]),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 60,
            vertical: 16,
          ),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: WiggleWidget(
                      child: Image.asset('assets/logos/hackberry_1.png')),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Image.asset('assets/logos/hackberry_2.png'),
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white70,
                    ),
                  ),
                  child: const Text(
                    'Password',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // color: Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white70,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'LOGIN',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Forgot password',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class WiggleWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const WiggleWidget({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<WiggleWidget> createState() => _WiggleWidgetState();
}

class _WiggleWidgetState extends State<WiggleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _timer = Timer.periodic(widget.duration, (_) {
      _controller.forward(from: 0.0).then((_) {
        _controller.reverse();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      alignment: Alignment.bottomLeft,
      turns: Tween(
        begin: 0.0,
        end: 0.1,
      ).animate(
        CurvedAnimation(
          curve: Curves.ease,
          parent: _controller,
        ),
      ),
      child: widget.child,
    );
  }
}

const outerColor = Color(0xff3c2b79);
const innerColor = Color(0xff594a8f);
