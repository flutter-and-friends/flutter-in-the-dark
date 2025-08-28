import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';

@immutable
class ChallengeBase {
  final String name;
  final String dartPadId;
  final String challengeId;
  final Map<String, String> assets;
  final Map<String, dynamic> widgetJson;

  ChallengeBase({
    required this.name,
    required this.dartPadId,
    required this.challengeId,
    required this.assets,
    required this.widgetJson,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'dartPadId': dartPadId,
    'challengeId': challengeId,
    'assets': assets,
    'widgetJson': widgetJson,
  };

  late final jsonWidgetData = JsonWidgetData.fromDynamic(widgetJson);

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

  factory ChallengeBase.fromJson(Map<String, dynamic> data) {
    final {
      'name': String name,
      'dartPadId': String dartPadId,
      'challengeId': String challengeId,
      'assets': Map<String, dynamic>? assets,
      'widgetJson': Map<String, dynamic> widgetJson,
    } = data;
    return ChallengeBase(
      name: name,
      dartPadId: dartPadId,
      challengeId: challengeId,
      assets: assets?.cast() ?? const {},
      widgetJson: widgetJson,
    );
  }
}

class Challenge extends ChallengeBase {
  final DateTime startTime;
  final DateTime endTime;

  Challenge({
    required super.name,
    required super.dartPadId,
    required super.challengeId,
    required super.assets,
    required super.widgetJson,
    required this.startTime,
    required this.endTime,
  });

  bool get isInTheFuture => startTime.isAfter(DateTime.now());

  bool get isFinished => DateTime.now().isAfter(endTime);

  static Challenge? fromJson(Map<String, dynamic>? data) {
    switch (data) {
      case {
        'name': final String name,
        'startTime': final Timestamp startTime,
        'endTime': final Timestamp endTime,
        'dartPadId': final String dartPadId,
        'challengeId': final String challengeId,
        'widgetJson': final Map<String, dynamic> widgetJson,
        'assets': final Map<String, dynamic>? assets,
      }:
        return Challenge(
          name: name,
          dartPadId: dartPadId,
          challengeId: challengeId,
          startTime: startTime.toDate(),
          endTime: endTime.toDate(),
          assets: assets?.cast() ?? const {},
          widgetJson: widgetJson,
        );
    }
    return null;
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
