import 'package:cloud_firestore/cloud_firestore.dart';

class Player {
  final String id;
  final String name;
  final PlayerStatus status;

  Player({
    required this.id,
    required this.name,
    this.status = PlayerStatus.inProgress,
  });

  factory Player.fromFirestore(DocumentSnapshot doc) {
    final {'name': String name, 'status': String status} =
        doc.data()! as Map<String, dynamic>;
    return Player(
      id: doc.id,
      name: name,
      status: PlayerStatus.fromString(status),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'status': status.name};
  }

  Player withStatus(PlayerStatus newStatus) {
    return Player(id: id, name: name, status: newStatus);
  }
}

enum PlayerStatus {
  inProgress,
  blocked;

  static PlayerStatus fromString(String status) {
    switch (status) {
      case 'inProgress':
        return PlayerStatus.inProgress;
      case 'blocked':
        return PlayerStatus.blocked;
      default:
        throw ArgumentError('Unknown status: $status');
    }
  }

  @override
  String toString() => name;
}
