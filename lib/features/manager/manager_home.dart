import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/app_user.dart';
import '../../models/item.dart';
import '../../models/sale.dart';
import '../../models/waiter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cafe_provider.dart';
import '../../providers/sales_provider.dart';
import '../../services/sales_service.dart';

class ManagerHome extends ConsumerWidget {
  const ManagerHome({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cafeId = user.cafeId;
    final shopId = user.shopId;

    Widget body;
    String title = 'Hisaab';

    if (cafeId == null || shopId == null) {
      body = const Center(child: Text('This account is not linked to a shop.'));
    } else {
      final shops = ref.watch(shopsProvider(cafeId)).valueOrNull ?? const [];
      for (final s in shops) {
        if (s.id == shopId) title = s.name;
      }
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OrderForm(user: user, cafeId: cafeId, shopId: shopId),
            const Divider(height: 1),
            _TodayOrders(cafeId: cafeId, shopId: shopId),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _OrderForm extends ConsumerStatefulWidget {
  const _OrderForm(
      {required this.user, required this.cafeId, required this.shopId});
  final AppUser user;
  final String cafeId;
  final String shopId;

  @override
  ConsumerState<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<_OrderForm> {
  Waiter? _waiter;
  Item? _item;
  int _qty = 1;
  int _itemFieldKey = 0; // bumping this clears the item dropdown
  final List<OrderLine> _cart = [];
  bool _busy = false;

  num get _cartTotal =>
      _cart.fold<num>(0, (s, l) => s + l.item.price * l.qty);

  void _addToCart() {
    final item = _item;
    if (item == null) return;
    setState(() {
      final i = _cart.indexWhere((l) => l.item.id == item.id);
      if (i >= 0) {
        _cart[i] = (item: item, qty: _cart[i].qty + _qty);
      } else {
        _cart.add((item: item, qty: _qty));
      }
      _item = null;
      _qty = 1;
      _itemFieldKey++;
    });
  }

  Future<void> _place() async {
    final waiter = _waiter;
    if (waiter == null || _cart.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(salesServiceProvider).addOrder(
            cafeId: widget.cafeId,
            shopId: widget.shopId,
            managerUid: widget.user.uid,
            waiter: waiter,
            lines: List.of(_cart),
          );
      if (!mounted) return;
      // Keep the waiter selected for the next order.
      setState(() => _cart.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save order: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiters = (ref.watch(waitersProvider(widget.cafeId)).valueOrNull ??
            const <Waiter>[])
        .where((w) => w.shopId == widget.shopId)
        .toList();
    final items =
        ref.watch(itemsProvider(widget.cafeId)).valueOrNull ?? const <Item>[];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<Waiter>(
            initialValue: waiters.where((w) => w.id == _waiter?.id).firstOrNull,
            decoration: const InputDecoration(
                labelText: 'Waiter', border: OutlineInputBorder()),
            hint: Text(waiters.isEmpty ? 'No waiters for this shop' : 'Select'),
            items: [
              for (final w in waiters)
                DropdownMenuItem(value: w, child: Text(w.name)),
            ],
            onChanged: (w) => setState(() => _waiter = w),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Item>(
            key: ValueKey(_itemFieldKey),
            initialValue: _item,
            decoration: const InputDecoration(
                labelText: 'Item', border: OutlineInputBorder()),
            hint: Text(items.isEmpty ? 'No items in menu' : 'Select'),
            items: [
              for (final i in items)
                DropdownMenuItem(
                    value: i,
                    child: Text('${i.name} · ${formatPrice(i.price)}')),
            ],
            onChanged: (i) => setState(() => _item = i),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.outlined(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 48,
                child: Text('$_qty',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
              ),
              IconButton.outlined(
                onPressed: () => setState(() => _qty++),
                icon: const Icon(Icons.add),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _item == null ? null : _addToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to order'),
              ),
            ],
          ),
          if (_cart.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _cart.length; i++)
                    ListTile(
                      dense: true,
                      title: Text('${_cart[i].qty} × ${_cart[i].item.name}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatPrice(_cart[i].item.price * _cart[i].qty)),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _cart.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text('Order total', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Text(formatPrice(_cartTotal),
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                (_waiter == null || _cart.isEmpty || _busy) ? null : _place,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_waiter == null && _cart.isNotEmpty
                ? 'Select a waiter'
                : 'Place order'),
          ),
        ],
      ),
    );
  }
}

class _TodayOrders extends ConsumerWidget {
  const _TodayOrders({required this.cafeId, required this.shopId});
  final String cafeId;
  final String shopId;

  String _time(DateTime? t) {
    if (t == null) return '';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _undo(BuildContext context, WidgetRef ref, SaleOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this order?'),
        content: Text('${o.lines.length} item(s) by ${o.waiterName}, '
            'total ${formatPrice(o.total)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(salesServiceProvider).deleteOrder(cafeId, o);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales =
        ref.watch(todaySalesProvider((cafeId: cafeId, shopId: shopId)));
    return sales.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Could not load sales: $e'))),
      data: (lines) {
        final orders = SaleOrder.group(lines);
        final total = lines.fold<num>(0, (sum, s) => sum + s.total);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text("Today's orders (${orders.length})",
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text(formatPrice(total),
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            if (orders.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No orders yet today.'))),
            for (final o in orders) ...[
              ListTile(
                title: Text(o.lines.map((l) => '${l.qty} × ${l.itemName}').join(', ')),
                subtitle: Text('${o.waiterName} · ${_time(o.createdAt)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatPrice(o.total),
                        style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      tooltip: 'Remove order',
                      icon: const Icon(Icons.undo),
                      onPressed: () => _undo(context, ref, o),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }
}
