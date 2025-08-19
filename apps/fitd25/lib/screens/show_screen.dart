import 'package:fitd25/providers/current_challenge_provider.dart';
import 'package:fitd25/screens/home_screen.dart';
import 'package:fitd25/widgets/countdown_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

class ShowScreen extends ConsumerWidget {
  const ShowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(currentChallengeProvider);

    return challengeAsync.when(
      data: (challenge) {
        if (challenge == null) {
          return const HomeScreen();
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

                  if (remainingTime.isNegative ||
                      remainingTime.inSeconds > 10) {
                    return Container();
                  }

                  return CountdownOverlay(duration: remainingTime);
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Error: $error')),
    );
  }
}
