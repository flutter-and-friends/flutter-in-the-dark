import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:flutter/material.dart';

mixin AllPlayersMixin<T extends StatefulWidget> on State<T> {
  List<Player>? _allPlayers;

  List<Player> get allPlayers => _allPlayers ?? const [];

  late final StreamSubscription<dynamic> _playersSubscription;

  @override
  void initState() {
    super.initState();

    _playersSubscription = FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _allPlayers = snapshot.docs
                .map(Player.fromFirestore)
                .nonNulls
                .toList(growable: false);
          });
        });
  }

  Future<void> updateChallenger(Player challenger) {
    return FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .doc(challenger.id)
        .set(challenger.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteChallenger(Player challenger) {
    return FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .doc(challenger.id)
        .delete();
  }

  Future<void> clearAllPlayers() async {
    final players = await FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in players.docs) {
      batch.delete(doc.reference);
    }
    return batch.commit();
  }

  @override
  void dispose() {
    _playersSubscription.cancel();
    super.dispose();
  }
}
