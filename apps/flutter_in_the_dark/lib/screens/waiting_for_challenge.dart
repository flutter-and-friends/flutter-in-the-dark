import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/room/room_client.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/widgets/burn_reveal.dart';
import 'package:flutter_in_the_dark/widgets/compiled_widget.dart';
import 'package:flutter_in_the_dark/widgets/countdown_overlay.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

/// The "challenge starts in N" screen. The challenge (and thus its
/// `widgetUrl`) is already known here, so the compiled challenge iframe is
/// mounted IMMEDIATELY underneath the overlay — it loads hidden while the
/// countdown runs (the backend pre-warms the artifact; this pre-warms the
/// browser's fetch+boot of it). At zero the overlay burns away center-out
/// (~1 s) revealing the already-loaded challenge.
///
/// The countdown is driven by the host screen's wall-clock ticker (I-008):
/// Timeago below re-runs its builder every second and feeds
/// [BurnRevealController.tick], so the countdown → burn → reveal handoff is
/// Listenable-driven, never a bare `DateTime.now()` gate in `build`.
class WaitingForChallenge extends StatefulWidget {
  final Challenge challenge;

  const WaitingForChallenge({super.key, required this.challenge});

  @override
  State<WaitingForChallenge> createState() => _WaitingForChallengeState();
}

class _WaitingForChallengeState extends State<WaitingForChallenge>
    with SingleTickerProviderStateMixin {
  late final BurnRevealController _burn;

  @override
  void initState() {
    super.initState();
    _burn = BurnRevealController(vsync: this);
  }

  @override
  void dispose() {
    _burn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    return Scaffold(
      body: Timeago(
        refreshRate: const Duration(seconds: 1),
        date: challenge.startTime.toLocal(),
        allowFromNow: true,
        builder: (context, time) {
          final remainingTime = challenge.startTime.difference(DateTime.now());
          _burn.tick(remainingTime);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Pre-warmed challenge iframe — mounted from the moment the
              // challenge is known, hidden behind the overlay until the burn
              // reveals it. An empty widgetUrl (uncompiled challenge)
              // renders the same placeholder the live screens use.
              if (challenge.widgetUrl.isNotEmpty)
                CompiledWidget(
                  url: '${RoomClient.compileBaseUrl}${challenge.widgetUrl}',
                )
              else
                const Center(
                  child: Text(
                    'Challenge widget coming soon…',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              // Opaque until the reveal: the >10 s "Starting in N" text,
              // then the 10→0 countdown, then the burn itself. The overlay
              // self-blocks pointer input (PointerInterceptor inside
              // BurnRevealOverlay) the whole time it is up — the pre-warmed
              // iframe underneath must NOT be interactable while it is
              // still hidden (the challenge hasn't started yet).
              if (!_burn.isRevealed)
                BurnRevealOverlay(
                  controller: _burn,
                  remaining: remainingTime,
                  waitingBuilder: (context) => ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: Text(
                        'Starting "${challenge.name}" in $time',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  countdownBuilder: (context) =>
                      CountdownOverlay(duration: remainingTime),
                ),
            ],
          );
        },
      ),
    );
  }
}
