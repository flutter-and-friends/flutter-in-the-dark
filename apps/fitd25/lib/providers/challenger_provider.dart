import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/data/challenger.dart';
import 'package:fitd25/providers/firestore_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});

final challengerProvider = StreamProvider<Player?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final user = ref.watch(authProvider).value;

  if (user == null) {
    return Stream.value(null);
  }

  final stream = firestore
      .collection('fitd')
      .doc('state')
      .collection('challengers')
      .doc(user.uid)
      .snapshots();

  return stream.map((snapshot) {
    if (snapshot.exists) {
      return Player.fromFirestore(snapshot);
    } else {
      return null;
    }
  });
});

Future<void> createChallenger(WidgetRef ref, String name) async {
  final user = await FirebaseAuth.instance.signInAnonymously().then(
    (e) => e.user,
  );
  if (user == null) {
    throw StateError('User must be signed in to create a challenger');
  }

  final challenger = Player(id: user.uid, name: name);
  return updateChallenger(ref, challenger);
}

Future<void> updateChallenger(WidgetRef ref, Player challenger) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('fitd')
      .doc('state')
      .collection('challengers')
      .doc(challenger.id)
      .set(challenger.toFirestore());
}
