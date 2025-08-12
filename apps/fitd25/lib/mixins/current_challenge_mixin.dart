import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:flutter/material.dart';

mixin CurrentChallengeMixin<T extends StatefulWidget> on State<T> {
  late final StreamSubscription _challengeSubscription;
  Challenge? challenge;
  Timer? _finishTimer;
  Timer? _startTimer;

  void onChallengeStart() {}

  void onChallengeEnd() {}

  void onChallengeChanged() {}

  void countStart(DateTime startTime) {
    _startTimer?.cancel();
    _startTimer = null;

    // If the start time is in the past, we don't need to set a timer
    if (DateTime.now().isAfter(startTime)) {
      onChallengeStart();
      return;
    }

    _startTimer = Timer(startTime.difference(DateTime.now()), () {
      setState(() {
        _startTimer?.cancel();
        _startTimer = null;

        onChallengeStart();
      });
    });
  }

  void countFinish(DateTime endTime) {
    _finishTimer?.cancel();
    _finishTimer = null;

    // If the end time is in the past, we don't need to set a timer
    if (DateTime.now().isAfter(endTime)) {
      onChallengeEnd();
      return;
    }

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
          final oldChallengeId = challenge?.challengeId;
          final data = snapshot.data();
          challenge = Challenge.fromJson(data);

          if (oldChallengeId != challenge?.challengeId) {
            onChallengeChanged();
          }

          setState(() {
            if (challenge case final challenge?) {
              countStart(challenge.startTime);
              countFinish(challenge.endTime);
            }
          });
        });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _finishTimer?.cancel();
    _challengeSubscription.cancel();
    super.dispose();
  }
}
