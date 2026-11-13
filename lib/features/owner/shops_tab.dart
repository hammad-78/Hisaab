import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/item.dart';
import '../../models/sale.dart';
import '../../models/shop.dart';
import '../../models/waiter.dart';
import '../../providers/cafe_provider.dart';
import '../../providers/sales_provider.dart';

/// Today's figures for one shop.
class _ShopToday {
  num amount = 0;
  final orders = <String>{};
}

class ShopsTab extends ConsumerWidget {
  const ShopsTab({super.key, required this.user, required this.cafeId});
  final AppUser user;
  final String cafeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayKey(DateTime.now());
    final shopsAsync = ref.watch(shopsProvider(cafeId));
    final shops = shopsAsync.valueOrNull ?? const <Shop>[];
    final waiters = ref.watch(waitersProvider(cafeId)).valueOrNull ?? const <Waiter>[];
    final items = ref.watch(itemsProvider(cafeId)).valueOrNull ?? const <Item>[];
    final cafeName = ref.watch(cafeNameProvider(cafeId)).valueOrNull ?? '';

    // One live listener on today's sales for the whole cafe, split by shop.
    final salesAsync =
        ref.watch(rangeSalesProvider((cafeId: cafeId, from: today, to: today)));
    final sales = salesAsync.valueOrNull;
    final byShop = <String, _ShopToday>{};
    for (final Sale s in sales ?? const []) {
      (byShop[s.shopId] ??= _ShopToday())
        ..amount += s.total
        ..orders.add(s.orderId);
    }
    final todayTotal = byShop.values.fold<num>(0, (t, s) => t + s.amount);
    final todayOrders = byShop.values.fold<int>(0, (t, s) => t + s.orders.length);

    if (shopsAsync.hasError) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Shops could not be loaded. ${shopsAsync.error}')));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _OwnerCard(
          user: user,
          cafeName: cafeName,
          todayTotal: sales == null ? null : todayTotal,
          todayOrders: todayOrders,
          shopCount: shops.length,
          waiterCount: waiters.length,
          itemCount: items.length,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('Shops', style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(),
        if (shopsAsync.isLoading && shops.isEmpty)
          const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()))
        else if (shops.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
                'No shops yet. Tap "Add shop" to create one and give its manager a login.',
                textAlign: TextAlign.center),
          )
        else
          for (final s in shops) ...[
            _ShopRow(
              shop: s,
              waiters: waiters.where((w) => w.shopId == s.id).toList(),
              today: sales == null ? null : (byShop[s.id] ?? _ShopToday()),
            ),
            const Divider(),
          ],
      ],
    );
  }
}

/// The owner's own block: who they are, and the cafe's day at a glance.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.user,
    required this.cafeName,
    required this.todayTotal,
    required this.todayOrders,
    required this.shopCount,
    required this.waiterCount,
    required this.itemCount,
  });

  final AppUser user;
  final String cafeName;
  final num? todayTotal; // null while loading
  final int todayOrders;
  final int shopCount;
  final int waiterCount;
  final int itemCount;

  String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final initials = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();

    return Container(
      color: HColors.slip,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: HColors.inkSoft,
                child: Text(initials,
                    style: t.titleMedium?.copyWith(color: HColors.ink)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: t.titleLarge, overflow: TextOverflow.ellipsis),
                    Text(user.email,
                        style: t.bodyMedium?.copyWith(color: HColors.pencil),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(cafeName.isEmpty ? 'Sales today' : '$cafeName sales today',
              style: t.bodyLarge?.copyWith(color: HColors.pencil)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Ruled off like a ledger total.
              Container(
                padding: const EdgeInsets.only(bottom: 3),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: HColors.ink, width: 1.5))),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: HColors.ink, width: 1.5))),
                  child: Text(
                    todayTotal == null ? 'Rs ...' : formatMoney(todayTotal!),
                    style: t.headlineMedium?.copyWith(
                        color: HColors.ink, fontFeatures: tabular),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_plural(todayOrders, 'order', 'orders'),
                    style: t.bodyLarge),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Fact(value: shopCount, label: shopCount == 1 ? 'shop' : 'shops'),
              _Fact(value: waiterCount, label: waiterCount == 1 ? 'waiter' : 'waiters'),
              _Fact(value: itemCount, label: itemCount == 1 ? 'menu item' : 'menu items'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: t.titleLarge?.copyWith(fontFeatures: tabular)),
          Text(label, style: t.bodyMedium?.copyWith(color: HColors.pencil)),
        ],
      ),
    );
  }
}

/// One shop: tap to open its manager, waiters and live sales for today.
class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.shop, required this.waiters, required this.today});
  final Shop shop;
  final List<Waiter> waiters;
  final _ShopToday? today; // null while loading

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final amount = today == null ? 'Rs ...' : formatMoney(today!.amount);

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      backgroundColor: HColors.slip,
      tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      leading: const Icon(Icons.storefront),
      title: Text(shop.name, style: t.titleMedium),
      subtitle: Text('Today $amount',
          style: t.bodyMedium?.copyWith(color: HColors.pencil, fontFeatures: tabular)),
      children: [
        _row(context, 'Manager', shop.managerName, shop.managerEmail),
        _row(
          context,
          'Waiters',
          '${waiters.length}',
          waiters.isEmpty
              ? 'None yet. Add them in the Waiters tab.'
              : waiters.map((w) => w.name).join(', '),
        ),
        _row(
          context,
          'Today',
          amount,
          today == null
              ? null
              : '${today!.orders.length} ${today!.orders.length == 1 ? 'order' : 'orders'}, updates live',
          highlight: true,
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, String? sub,
      {bool highlight = false}) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HColors.rule))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 88,
              child: Text(label, style: t.bodyMedium?.copyWith(color: HColors.pencil))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: (highlight ? t.titleMedium : t.bodyLarge)?.copyWith(
                        color: highlight ? HColors.ink : null,
                        fontFeatures: tabular)),
                if (sub != null)
                  Text(sub, style: t.bodySmall?.copyWith(color: HColors.pencil)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
