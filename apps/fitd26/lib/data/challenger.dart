import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore shape (fitd26):
/// `fitd/state/challengers/{uid}` →
///   `{name: String, status: 'inProgress'|'blocked', prompt: String,
///     generatedCode: String?}`
class Player {
  final String id;
  final String name;
  final PlayerStatus status;
  final String prompt;
  final String? generatedCode;

  Player({
    required this.id,
    required this.name,
    this.status = PlayerStatus.inProgress,
    this.prompt = '',
    this.generatedCode,
  });

  static Player? fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data is! Map<String, dynamic>) return null;
    final {'name': String name, 'status': String status} = data;
    return Player(
      id: doc.id,
      name: name,
      status: PlayerStatus.fromString(status),
      prompt: switch (data['prompt']) {
        final String prompt => prompt,
        _ => '',
      },
      generatedCode: switch (data['generatedCode']) {
        final String code => code,
        _ => null,
      },
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'status': status.name};
  }

  Player withStatus(PlayerStatus newStatus) {
    return Player(
      id: id,
      name: name,
      status: newStatus,
      prompt: prompt,
      generatedCode: generatedCode,
    );
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
