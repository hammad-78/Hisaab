import 'package:cloud_firestore/cloud_firestore.dart';

/// A menu item. Each shop has its own menu, managed by that shop's manager.
class Item {
  final String id;
  final String name;
  final num price;

  /// Empty for items created before menus became per-shop.
  final String shopId;

  const Item({
    required this.id,
    required this.name,
    required this.price,
    this.shopId = '',
  });

  factory Item.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Item(
      id: d.id,
      name: (m['name'] ?? '') as String,
      price: (m['price'] ?? 0) as num,
      shopId: (m['shopId'] ?? '') as String,
    );
  }
}
