import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class ChallengeBase {
  final String name;
  final String dartPadId;
  final String challengeId;
  final List<String> imageUrls;
  final Map<String, dynamic> widgetJson;

  ChallengeBase({
    required this.name,
    required this.dartPadId,
    required this.challengeId,
    required this.imageUrls,
    required this.widgetJson,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'dartPadId': dartPadId,
    'challengeId': challengeId,
    'imageUrls': imageUrls,
    'widgetJson': widgetJson,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeBase &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          dartPadId == other.dartPadId &&
          challengeId == other.challengeId &&
          const DeepCollectionEquality().equals(widgetJson, other.widgetJson);

  @override
  int get hashCode => Object.hash(name, dartPadId, challengeId, widgetJson);
}

class Challenge extends ChallengeBase {
  final DateTime startTime;
  final DateTime endTime;

  Challenge({
    required super.name,
    required super.dartPadId,
    required super.challengeId,
    required super.imageUrls,
    required super.widgetJson,
    required this.startTime,
    required this.endTime,
  });

  factory Challenge.fromFirestore(Map<String, dynamic> data) {
    switch (data) {
      case {
        'name': final String name,
        'startTime': final Timestamp startTime,
        'endTime': final Timestamp endTime,
        'dartPadId': final String dartPadId,
        'challengeId': final String challengeId,
        'widgetJson': final Map<String, dynamic> widgetJson,
        'imageUrls': final List<dynamic>? imageUrls,
      }:
        return Challenge(
          name: name,
          dartPadId: dartPadId,
          challengeId: challengeId,
          startTime: startTime.toDate(),
          endTime: endTime.toDate(),
          imageUrls: imageUrls?.cast() ?? const [],
          widgetJson: widgetJson,
        );
    }
    throw ArgumentError('Invalid data format for Challenge');
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'startTime': startTime,
    'endTime': endTime,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      // Let the super class check its fields.
      super == other &&
          other is Challenge &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  // Let the super class compute its hash code and combine it with the new fields.
  int get hashCode => Object.hash(super.hashCode, startTime, endTime);
}
