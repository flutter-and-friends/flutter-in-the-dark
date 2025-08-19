import 'dart:async';

import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/providers/firestore_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'all_players_provider.g.dart';

@riverpod
class AllPlayers extends _$AllPlayers {
  @override
  Stream<List<Player>> build() {
    final firestore = ref.watch(firestoreProvider);
    final stream = firestore
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .snapshots();

    return stream.map((snapshot) {
      return snapshot.docs
          .map(Player.fromFirestore)
          .where((player) => player != null)
          .cast<Player>()
          .toList(growable: false);
    });
  }

  Future<void> updatePlayer(Player challenger) {
    final firestore = ref.read(firestoreProvider);
    return firestore
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .doc(challenger.id)
        .set(challenger.toFirestore());
  }

  Future<void> deletePlayer(Player challenger) {
    final firestore = ref.read(firestoreProvider);
    return firestore
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .doc(challenger.id)
        .delete();
  }

  Future<void> clearAllPlayers() async {
    final firestore = ref.read(firestoreProvider);
    final players = await firestore
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .get();
    final batch = firestore.batch();
    for (final doc in players.docs) {
      batch.delete(doc.reference);
    }
    return batch.commit();
  }
}
