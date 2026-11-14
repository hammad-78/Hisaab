import 'package:cloud_firestore/cloud_firestore.dart';

class Shop {
  final String id;
  final String name;
  final String managerUid;
  final String managerName;
  final String managerEmail;
  final bool active;

  const Shop({
    required this.id,
    required this.name,
    required this.managerUid,
    required this.managerName,
    required this.managerEmail,
    this.active = true,
  });

  factory Shop.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Shop(
      id: d.id,
      name: (m['name'] ?? '') as String,
      managerUid: (m['managerUid'] ?? '') as String,
      managerName: (m['managerName'] ?? '') as String,
      managerEmail: (m['managerEmail'] ?? '') as String,
      active: (m['active'] ?? true) as bool,
    );
  }
}
