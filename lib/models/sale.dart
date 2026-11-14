import 'package:cloud_firestore/cloud_firestore.dart';

/// One order = several sale lines that share an orderId.
class SaleOrder {
  final String orderId;
  final String waiterName;
  final DateTime? createdAt;
  final List<Sale> lines;

  const SaleOrder({
    required this.orderId,
    required this.waiterName,
    required this.createdAt,
    required this.lines,
  });

  num get total => lines.fold<num>(0, (s, l) => s + l.total);

  bool get cancelled => lines.every((l) => l.cancelled);

  /// Groups lines into orders, keeping the incoming (newest-first) order.
  /// Older single-item sales without an orderId become one-line orders.
  static List<SaleOrder> group(List<Sale> sales) {
    final byId = <String, List<Sale>>{};
    for (final s in sales) {
      (byId[s.orderId] ??= []).add(s);
    }
    return [
      for (final e in byId.entries)
        SaleOrder(
          orderId: e.key,
          waiterName: e.value.first.waiterName,
          createdAt: e.value.first.createdAt,
          lines: e.value,
        ),
    ];
  }
}

class Sale {
  final String id;
  final String orderId;
  final String shopId;
  final String waiterId;
  final String waiterName;
  final String itemId;
  final String itemName;
  final int qty;
  final num unitPrice;
  final num total;
  final String day;
  final DateTime?
  createdAt; // null briefly while the server timestamp is pending
  final bool cancelled; // cancelled orders are kept but excluded from totals

  const Sale({
    required this.id,
    required this.orderId,
    required this.shopId,
    required this.waiterId,
    required this.waiterName,
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
    required this.total,
    required this.day,
    required this.createdAt,
    this.cancelled = false,
  });

  factory Sale.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Sale(
      id: d.id,
      orderId: (m['orderId'] ?? d.id) as String,
      shopId: (m['shopId'] ?? '') as String,
      waiterId: (m['waiterId'] ?? '') as String,
      waiterName: (m['waiterName'] ?? '') as String,
      itemId: (m['itemId'] ?? '') as String,
      itemName: (m['itemName'] ?? '') as String,
      qty: ((m['qty'] ?? 0) as num).toInt(),
      unitPrice: (m['unitPrice'] ?? 0) as num,
      total: (m['total'] ?? 0) as num,
      day: (m['day'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      cancelled: (m['cancelled'] ?? false) as bool,
    );
  }
}
