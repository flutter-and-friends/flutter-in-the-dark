import 'package:fitd25/mixins/current_challenge_mixin.dart';
import 'package:fitd25/screens/home_screen.dart';
import 'package:fitd25/screens/waiting_for_challenge.dart';
import 'package:fitd25/widgets/countdown_overlay.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

class ShowScreen extends StatefulWidget {
  const ShowScreen({super.key});

  @override
  State<ShowScreen> createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> with CurrentChallengeMixin {
  @override
  void onChallengeStart() {
    setState(() {});
  }

  @override
  void onChallengeEnd() {}

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;

    if (challenge == null) {
      return const HomeScreen();
    }

    if (challenge.isInTheFuture) {
      return WaitingForChallenge(challenge: challenge);
    }

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 430 / 764,
              child: FittedBox(
                child: SizedBox(
                  width: 430,
                  height: 764,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.grey.shade900, width: 12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: challenge.jsonWidgetData.build(context: context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            child: Timeago(
              refreshRate: const Duration(milliseconds: 100),
              date: challenge.endTime,
              allowFromNow: true,
              builder: (context, time) {
                final remainingTime = challenge.endTime.difference(
                  DateTime.now(),
                );
                if (remainingTime.isNegative) {
                  return const Text(
                    'Time over!',
                    style: TextStyle(fontSize: 48, color: Colors.red),
                  );
                }

                if (remainingTime.inSeconds > 10) {
                  return SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
          Timeago(
            refreshRate: const Duration(milliseconds: 100),
            date: challenge.endTime,
            allowFromNow: true,
            builder: (context, time) {
              final remainingTime = challenge.endTime.difference(
                DateTime.now(),
              );

              if (remainingTime.isNegative || remainingTime.inSeconds > 10) {
                return Container();
              }

              return CountdownOverlay(duration: remainingTime);
            },
          ),
        ],
      ),
    );
  }
}
