import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/providers/firestore_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allChallengesProvider = StreamProvider<List<ChallengeBase>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  final stream = firestore
      .collection('fitd')
      .doc('state')
      .collection('challenges')
      .snapshots();

  return stream.map((snapshot) {
    return snapshot.docs
        .map((doc) => ChallengeBase.fromJson(doc.data()))
        .toList(growable: false);
  });
});

Future<void> setCurrentChallenge(WidgetRef ref, Challenge challenge) {
  final firestore = ref.read(firestoreProvider);
  return firestore.doc('/fitd/state').set(challenge.toJson());
}

Future<void> saveChallenge(WidgetRef ref, ChallengeBase challenge) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .doc('/fitd/state/challenges/${challenge.challengeId}')
      .set(challenge.toJson());
}
