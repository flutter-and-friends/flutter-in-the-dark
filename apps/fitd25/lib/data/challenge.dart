class Challenge {
  final DateTime startTime;
  final DateTime endTime;
  final String name;
  final String dartPadId;
  final String challengeId;

  Challenge({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.dartPadId,
    required this.challengeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Challenge &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          name == other.name &&
          dartPadId == other.dartPadId &&
          challengeId == other.challengeId;

  @override
  int get hashCode =>
      Object.hash(startTime, endTime, name, dartPadId, challengeId);
}
