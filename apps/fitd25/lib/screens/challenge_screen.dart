import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/screens/waiting_for_challenge.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setLocaleMessages, setDefaultLocale;

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.challenge,
    required this.challenger,
    required this.confettiController,
  });

  final Challenge challenge;
  final Challenger challenger;
  final ConfettiController confettiController;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late final JsonWidgetData jsonWidgetData;

  @override
  void initState() {
    jsonWidgetData = JsonWidgetData.fromDynamic(widget.challenge.widgetJson);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('challengers')
          .doc(widget.challenger.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final challenger = Challenger.fromFirestore(snapshot.data!);

        if (challenger.status == 'blocked') {
          return const WaitingForChallenge(message: 'Your screen is blocked');
        }

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Text('Challenger: ${challenger.name}'),
                    const Spacer(),
                    switch (widget.challenge.endTime) {
                      final endTime when DateTime.now().isAfter(endTime) =>
                        const Text(
                          'Time over!',
                        ),
                      final endTime => Timeago(
                        refreshRate: const Duration(seconds: 1),
                        date: endTime,
                        allowFromNow: true,
                        builder: (context, time) {
                          if (DateTime.now().isAfter(endTime)) {
                            return const Text('Time over!');
                          }
                          return Text(
                              '"${widget.challenge.name}" ends in $time');
                        },
                      ),
                    },
                  ],
                ),
              ),
              body: SplitPane(
                axis: Axis.horizontal,
                initialFractions: [0.4, 0.4, 0.2],
                children: [
                  jsonWidgetData.build(context: context),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return DartPad(
                        key: Key(widget.challenge.dartPadId),
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        split: 100,
                        gistId: widget.challenge.dartPadId,
                      );
                    },
                  ),
                  Column(
                    children: [
                      Text(
                        'Images for challenge',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (widget.challenge.imageUrls.isEmpty)
                        const Center(
                            child: Text('No images for this challenge'))
                      else
                        Expanded(
                          child: ListView(
                            children: [
                              for (final url in widget.challenge.imageUrls)
                                ListTile(
                                  title: Text(url),
                                  subtitle: Image.network(url),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            ConfettiWidget(
              confettiController: widget.confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              strokeWidth: 2,
            ),
          ],
        );
      },
    );
  }
}
