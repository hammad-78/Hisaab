import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/models/report.dart';
import 'package:hisaab/models/sale.dart';
import 'package:hisaab/services/report_export.dart';

Sale _line(String id, String order, String shop, String waiter, String item,
        int qty, num price) =>
    Sale(
      id: id,
      orderId: order,
      shopId: shop,
      waiterId: waiter,
      waiterName: 'W-$waiter',
      itemId: item,
      itemName: 'I-$item',
      qty: qty,
      unitPrice: price,
      total: price * qty,
      day: '2026-11-13',
      createdAt: null,
    );

void main() {
  final sales = [
    _line('1', 'o1', 's1', 'w1', 'tea', 2, 50), // 100
    _line('2', 'o1', 's1', 'w1', 'cake', 1, 20.5), // 20.5
    _line('3', 'o2', 's2', 'w2', 'tea', 3, 50), // 150
    _line('4', 'o3', 'gone', 'w3', 'tea', 1, 50), // 50, deleted shop
  ];

  Report build() => Report.from(
        sales: sales,
        shopNames: {'s1': 'SSA', 's2': 'UET'},
        fromDay: '2026-11-13',
        toDay: '2026-11-13',
        shopLabel: 'All shops',
      );

  test('totals and grouping', () {
    final r = build();
    expect(r.total, 320.5);
    expect(r.orders, 3);
    expect(r.itemsSold, 7);

    expect(r.byShop.map((l) => (l.name, l.count, l.amount)).toList(), [
      ('UET', 1, 150),
      ('SSA', 1, 120.5),
      ('Deleted shop', 1, 50),
    ]);
    expect(r.byItem.first.name, 'I-tea');
    expect(r.byItem.first.count, 6); // qty, not orders
    expect(r.byItem.first.amount, 300);
    expect(r.byWaiter.first.name, 'W-w2');
    expect(r.byWaiter.first.sub, 'UET');
  });

  test('empty report', () {
    final r = Report.from(
        sales: const [],
        shopNames: const {},
        fromDay: 'a',
        toDay: 'a',
        shopLabel: 'All shops');
    expect(r.isEmpty, isTrue);
  });

  test('PDF builds', () async {
    final bytes = await ReportExport.buildPdf(build(), cafeName: 'Test Cafe');
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('Excel builds and reads back', () {
    final bytes = ReportExport.buildExcel(build(), cafeName: 'Test Cafe');
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys,
        containsAll(['Summary', 'By shop', 'By item', 'By waiter']));
    expect(book.tables.keys, isNot(contains('Sheet1')));
    expect(book.tables['By shop']!.maxRows, 4); // header + 3 shops
  });
}
