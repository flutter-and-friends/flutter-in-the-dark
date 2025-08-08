import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:flutter/material.dart';

mixin CurrentChallengerMixin<T extends StatefulWidget> on State<T> {
  late final StreamSubscription _challengerSubscription;
  Challenger? challenger;

  /// This method is called when the challenger document is not found or fails
  /// to fetch.
  ///
  /// You can override this method to handle the case when the challenger
  /// document does not exist or fails to fetch.
  /// For example, you might want to redirect to a selection screen.
  ///
  /// @return `true` if the the case was handled, `false` otherwise.
  bool onFailedToFetchChallenger() => false;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    // If the user is logged in as admin, we don't need to fetch the challenger
    // document, as it is not relevant for admin users.
    if (currentUser case final user? when !user.isAnonymous) return;
    FirebaseAuth.instance.signInAnonymously().then((userCredential) async {
      final user = userCredential.user!;

      _challengerSubscription = FirebaseFirestore.instance
          .collection('fitd')
          .doc('state')
          .collection('challengers')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              setState(() {
                challenger = Challenger.fromFirestore(snapshot);
              });
            } else {
              if (onFailedToFetchChallenger()) {
                return;
              }
              setState(() {
                challenger = null;
              });
            }
          });
    });
  }

  Future<void> createChallenger(String name) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User must be signed in to create a challenger');
    }

    final challenger = Challenger(id: user.uid, name: name);
    return updateChallenger(challenger);
  }

  Future<void> updateChallenger(Challenger challenger) {
    return FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .doc(challenger.id)
        .set(challenger.toFirestore(), SetOptions(merge: true));
  }

  @override
  void dispose() {
    _challengerSubscription.cancel();
    super.dispose();
  }
}
