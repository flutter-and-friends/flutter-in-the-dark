import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:flutter/material.dart';

mixin CurrentChallengeMixin<T extends StatefulWidget> on State<T> {
  late final StreamSubscription _challengeSubscription;
  Challenge? challenge;
  Timer? _finishTimer;

  void onChallengeEnd() {}

  void countFinish(DateTime endTime) {
    _finishTimer?.cancel();
    _finishTimer = null;

    // If the end time is in the past, we don't need to set a timer
    if (DateTime.now().isAfter(endTime)) return;

    _finishTimer = Timer(endTime.difference(DateTime.now()), () {
      setState(() {
        _finishTimer?.cancel();
        _finishTimer = null;

        onChallengeEnd();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _challengeSubscription = FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          final challenge = this.challenge = Challenge.fromJson(data);

          setState(() {
            if (challenge case final challenge?) {
              countFinish(challenge.endTime);
            }
          });
        });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _challengeSubscription.cancel();
    super.dispose();
  }
}
