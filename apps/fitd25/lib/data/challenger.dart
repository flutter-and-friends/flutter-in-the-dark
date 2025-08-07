import 'package:cloud_firestore/cloud_firestore.dart';

class Challenger {
  final String id;
  final String name;
  final String status;

  Challenger({
    required this.id,
    required this.name,
    this.status = 'in_progress',
  });

  factory Challenger.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Challenger(
      id: doc.id,
      name: data['name'] ?? '',
      status: data['status'] ?? 'in_progress',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'status': status,
    };
  }
}
