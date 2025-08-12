import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:flutter/material.dart';

mixin AllChallengersMixin<T extends StatefulWidget> on State<T> {
  List<Challenger>? _allChallengers;

  List<Challenger> get allChallengers => _allChallengers ?? const [];

  late final StreamSubscription _challengersSubscription;

  @override
  void initState() {
    super.initState();

    _challengersSubscription = FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _allChallengers = snapshot.docs
                .map(Challenger.fromFirestore)
                .nonNulls
                .toList(growable: false);
          });
        });
  }

  Future<void> updateChallenger(Challenger challenger) {
    return FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .doc(challenger.id)
        .set(challenger.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteChallenger(Challenger challenger) {
    return FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .doc(challenger.id)
        .delete();
  }

  @override
  void dispose() {
    _challengersSubscription.cancel();
    super.dispose();
  }
}
