import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/format.dart';
import '../models/item.dart';
import '../models/sale.dart';
import '../models/waiter.dart';

typedef OrderLine = ({Item item, int qty});

class SalesService {
  SalesService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _sales(String cafeId) =>
      _db.collection('cafes').doc(cafeId).collection('sales');

  /// Saves one order as one sale document per line, all written in a single
  /// batch with a shared orderId. Name and price are copied into each line so
  /// later menu changes never alter past reports.
  Future<void> addOrder({
    required String cafeId,
    required String shopId,
    required String managerUid,
    required Waiter waiter,
    required List<OrderLine> lines,
  }) {
    final col = _sales(cafeId);
    final orderId = col.doc().id;
    final day = dayKey(DateTime.now());
    final batch = _db.batch();
    for (final l in lines) {
      batch.set(col.doc(), {
        'orderId': orderId,
        'shopId': shopId,
        'waiterId': waiter.id,
        'waiterName': waiter.name,
        'itemId': l.item.id,
        'itemName': l.item.name,
        'qty': l.qty,
        'unitPrice': l.item.price,
        'total': l.item.price * l.qty,
        'day': day,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': managerUid,
      });
    }
    return batch.commit();
  }

  /// Today's sale lines for one shop, newest first. Both filters are equality
  /// checks, so no composite index is needed; sorting happens here.
  Stream<List<Sale>> salesForDay(String cafeId, String shopId, String day) =>
      _sales(cafeId)
          .where('shopId', isEqualTo: shopId)
          .where('day', isEqualTo: day)
          .snapshots()
          .map((q) {
        final list = q.docs.map(Sale.fromDoc).toList();
        // A line still waiting for its server timestamp is the newest.
        list.sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now()));
        return list;
      });

  /// All sale lines in the cafe between two day keys (inclusive).
  /// A range on a single field needs no composite index; shop filtering is
  /// done in the app so the owner never has to create one either.
  Stream<List<Sale>> salesInRange(String cafeId, String fromDay, String toDay) =>
      _sales(cafeId)
          .where('day', isGreaterThanOrEqualTo: fromDay)
          .where('day', isLessThanOrEqualTo: toDay)
          .snapshots()
          .map((q) => q.docs.map(Sale.fromDoc).toList());

  /// Removes a whole order (all of its lines) at once.
  Future<void> deleteOrder(String cafeId, SaleOrder order) {
    final batch = _db.batch();
    for (final l in order.lines) {
      batch.delete(_sales(cafeId).doc(l.id));
    }
    return batch.commit();
  }
}
