import 'sale.dart';

/// One row in a report section.
/// [count] is the number of orders (shops, waiters) or quantity sold (items).
class ReportLine {
  final String name;
  final String? sub;
  final int count;
  final num amount;

  const ReportLine(
      {required this.name, this.sub, required this.count, required this.amount});
}

class Report {
  final String fromDay;
  final String toDay;
  final String shopLabel; // "All shops" or the shop name
  final num total;
  final int orders;
  final int itemsSold;
  final List<ReportLine> byShop;
  final List<ReportLine> byItem;
  final List<ReportLine> byWaiter;

  const Report({
    required this.fromDay,
    required this.toDay,
    required this.shopLabel,
    required this.total,
    required this.orders,
    required this.itemsSold,
    required this.byShop,
    required this.byItem,
    required this.byWaiter,
  });

  bool get isEmpty => orders == 0;

  /// Builds a report from sale lines. [shopNames] maps shopId to name; lines
  /// for a shop that has since been deleted are labelled "Deleted shop".
  factory Report.from({
    required List<Sale> sales,
    required Map<String, String> shopNames,
    required String fromDay,
    required String toDay,
    required String shopLabel,
  }) {
    String shopName(String id) => shopNames[id] ?? 'Deleted shop';

    final shops = <String, _Acc>{};
    final items = <String, _Acc>{};
    final waiters = <String, _Acc>{};
    final allOrders = <String>{};
    num total = 0;
    var qty = 0;

    for (final s in sales) {
      total += s.total;
      qty += s.qty;
      allOrders.add(s.orderId);

      (shops[s.shopId] ??= _Acc(shopName(s.shopId))).add(s);
      (items[s.itemId] ??= _Acc(s.itemName)).add(s);
      (waiters[s.waiterId] ??= _Acc(s.waiterName, sub: shopName(s.shopId)))
          .add(s);
    }

    List<ReportLine> sorted(Map<String, _Acc> m, {bool qtyCount = false}) {
      final list = m.values
          .map((a) => ReportLine(
              name: a.name,
              sub: a.sub,
              count: qtyCount ? a.qty : a.orders.length,
              amount: a.amount))
          .toList();
      list.sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    }

    return Report(
      fromDay: fromDay,
      toDay: toDay,
      shopLabel: shopLabel,
      total: total,
      orders: allOrders.length,
      itemsSold: qty,
      byShop: sorted(shops),
      byItem: sorted(items, qtyCount: true),
      byWaiter: sorted(waiters),
    );
  }
}

class _Acc {
  _Acc(this.name, {this.sub});
  final String name;
  final String? sub;
  final orders = <String>{};
  var qty = 0;
  num amount = 0;

  void add(Sale s) {
    orders.add(s.orderId);
    qty += s.qty;
    amount += s.total;
  }
}
