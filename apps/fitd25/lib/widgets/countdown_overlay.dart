import 'package:fitd25/widgets/heartbeat_curve.dart';
import 'package:flutter/material.dart';

class CountdownOverlay extends StatelessWidget {
  const CountdownOverlay({super.key, required this.duration});

  final Duration duration;

  static const animationCurve = HeartbeatCurve();

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = duration.inSeconds;
    return Container(
      color: Colors.black54,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) {
            return DualTransitionBuilder(
              key: ValueKey(child.key),
              animation: animation,
              forwardBuilder: (context, animation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 2.0,
                      end: 1.0,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: animationCurve,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              reverseBuilder: (context, animation, child) {
                return FadeTransition(
                  opacity: Tween<double>(
                    begin: 1.0,
                    end: 0.0,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: animationCurve,
                    ),
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 1.0,
                      end: 0.0,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: animationCurve,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          child: Text(
            key: ValueKey(remainingSeconds),
            '$remainingSeconds',
            style: const TextStyle(
              fontSize: 150,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
