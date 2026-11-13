import 'package:cloud_firestore/cloud_firestore.dart';

class Waiter {
  final String id;
  final String name;
  final String shopId;

  const Waiter({required this.id, required this.name, required this.shopId});

  factory Waiter.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Waiter(
      id: d.id,
      name: (m['name'] ?? '') as String,
      shopId: (m['shopId'] ?? '') as String,
    );
  }
}
