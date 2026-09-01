import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/widgets/glitch_title.dart';

class WaitingForChallengeScreen extends StatelessWidget {
  static const path = "/home";

  const WaitingForChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop glow: the same midnight palette as the /show player
          // cards (#0D1117/#161B22), so a joining player's first frame
          // already feels like the game rather than a bare form.
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 1.3,
                colors: [Color(0xFF17202E), Color(0xFF0B0E14)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlitchTitle(
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 24, color: Color(0xFF58A6FF)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'One prompt. One widget. Beat the clock.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
