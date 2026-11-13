import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/sale.dart';
import '../services/sales_service.dart';

final salesServiceProvider = Provider<SalesService>((ref) => SalesService());

typedef ShopRef = ({String cafeId, String shopId});

final todaySalesProvider =
    StreamProvider.autoDispose.family<List<Sale>, ShopRef>((ref, s) {
  return ref
      .watch(salesServiceProvider)
      .salesForDay(s.cafeId, s.shopId, dayKey(DateTime.now()));
});

/// Day keys, e.g. from: 2026-11-01, to: 2026-11-13 (inclusive).
typedef RangeRef = ({String cafeId, String from, String to});

final rangeSalesProvider =
    StreamProvider.autoDispose.family<List<Sale>, RangeRef>((ref, r) {
  return ref
      .watch(salesServiceProvider)
      .salesInRange(r.cafeId, r.from, r.to);
});
