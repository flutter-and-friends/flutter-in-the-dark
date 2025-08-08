import 'package:cloud_firestore/cloud_firestore.dart';

class Challenger {
  final String id;
  final String name;
  final ChallengerStatus status;

  Challenger({
    required this.id,
    required this.name,
    this.status = ChallengerStatus.inProgress,
  });

  factory Challenger.fromFirestore(DocumentSnapshot doc) {
    final {'name': String name, 'status': String status} =
        doc.data() as Map<String, dynamic>;
    return Challenger(
      id: doc.id,
      name: name,
      status: ChallengerStatus.fromString(status),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'status': status.name};
  }

  Challenger withStatus(ChallengerStatus newStatus) {
    return Challenger(
      id: id,
      name: name,
      status: newStatus,
    );
  }
}

enum ChallengerStatus {
  inProgress,
  blocked;

  static ChallengerStatus fromString(String status) {
    switch (status) {
      case 'inProgress':
        return ChallengerStatus.inProgress;
      case 'blocked':
        return ChallengerStatus.blocked;
      default:
        throw ArgumentError('Unknown status: $status');
    }
  }

  @override
  String toString() => name;
}
