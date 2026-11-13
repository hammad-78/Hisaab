import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String name;
  final num price;

  const Item({required this.id, required this.name, required this.price});

  factory Item.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Item(
      id: d.id,
      name: (m['name'] ?? '') as String,
      price: (m['price'] ?? 0) as num,
    );
  }
}
