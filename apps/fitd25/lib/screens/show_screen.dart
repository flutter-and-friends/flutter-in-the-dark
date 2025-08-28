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
      appBar: AppBar(title: Text(challenge.name)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          challenge.jsonWidgetData.build(context: context),
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
                  return Text(
                    'Time remaining: $time',
                    style: const TextStyle(
                      fontSize: 48,
                      backgroundColor: Colors.black54,
                      color: Colors.white,
                    ),
                  );
                }

                return Container();
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
