import 'dart:async';

import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/providers/firestore_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_challenge_provider.g.dart';

@riverpod
class CurrentChallenge extends _$CurrentChallenge {
  @override
  Stream<Challenge?> build() {
    final firestore = ref.watch(firestoreProvider);
    final stream = firestore.collection('fitd').doc('state').snapshots();

    return stream.asyncMap((snapshot) async {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      final challengeId = data['current_challenge'] as String?;
      if (challengeId == null) {
        return null;
      }

      final challengeSnapshot =
          await firestore.collection('challenges').doc(challengeId).get();

      if (challengeSnapshot.exists) {
        return Challenge.fromJson(challengeSnapshot.data());
      } else {
        return null;
      }
    });
  }

  Future<void> clearCurrentChallenge() {
    final firestore = ref.read(firestoreProvider);
    return firestore.doc('/fitd/state').set({});
  }

  Future<void> updateChallengeTime(Duration duration) async {
    final challenge = await future;
    if (challenge == null) return;

    final newEndTime = challenge.endTime.add(duration);
    final firestore = ref.read(firestoreProvider);
    await firestore.doc('/fitd/state').update({
      'endTime': newEndTime,
    });
  }
}
