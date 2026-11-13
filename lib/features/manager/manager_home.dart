import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/item.dart';
import '../../models/waiter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cafe_provider.dart';
import '../../providers/sales_provider.dart';
import 'today_orders_screen.dart';
import 'widgets/order_slip.dart';

class ManagerHome extends ConsumerWidget {
  const ManagerHome({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cafeId = user.cafeId;
    final shopId = user.shopId;

    if (cafeId == null || shopId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hisaab'), actions: [_logout(ref)]),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'This login is not linked to a shop. Ask the cafe owner to add you as a shop manager.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final shops = ref.watch(shopsProvider(cafeId)).valueOrNull ?? const [];
    final shopName =
        shops.where((s) => s.id == shopId).map((s) => s.name).firstOrNull ?? '';
    final today =
        ref.watch(todaySalesProvider((cafeId: cafeId, shopId: shopId)));
    final todayOrders =
        today.valueOrNull?.map((s) => s.orderId).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(shopName),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    TodayOrdersScreen(cafeId: cafeId, shopId: shopId))),
            icon: const Icon(Icons.receipt_long),
            label: Text(todayOrders == null ? 'Today' : 'Today ($todayOrders)'),
          ),
          _logout(ref),
        ],
      ),
      body: _Counter(user: user, cafeId: cafeId, shopId: shopId),
    );
  }

  Widget _logout(WidgetRef ref) => IconButton(
        tooltip: 'Log out',
        icon: const Icon(Icons.logout),
        onPressed: () => ref.read(authServiceProvider).signOut(),
      );
}

/// The counter: pick a waiter, tap menu items to build the slip, place it.
class _Counter extends ConsumerStatefulWidget {
  const _Counter(
      {required this.user, required this.cafeId, required this.shopId});
  final AppUser user;
  final String cafeId;
  final String shopId;

  @override
  ConsumerState<_Counter> createState() => _CounterState();
}

class _CounterState extends ConsumerState<_Counter> {
  String? _waiterId;
  final Map<String, int> _qty = {}; // itemId -> qty, in the order tapped
  String _search = '';
  bool _busy = false;

  void _add(Item item) {
    HapticFeedback.selectionClick();
    setState(() => _qty[item.id] = (_qty[item.id] ?? 0) + 1);
  }

  void _change(String itemId, int delta) {
    setState(() {
      final q = (_qty[itemId] ?? 0) + delta;
      if (q <= 0) {
        _qty.remove(itemId);
      } else {
        _qty[itemId] = q;
      }
    });
  }

  Future<void> _place(Waiter waiter, List<SlipLine> lines, num total) async {
    setState(() => _busy = true);
    try {
      await ref.read(salesServiceProvider).addOrder(
            cafeId: widget.cafeId,
            shopId: widget.shopId,
            managerUid: widget.user.uid,
            waiter: waiter,
            lines: [for (final l in lines) (item: l.item, qty: l.qty)],
          );
      if (!mounted) return;
      setState(() => _qty.clear());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Order placed for ${waiter.name}: ${formatMoney(total)}')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Order not saved. Check your connection and try again. ($e)')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waiters = (ref.watch(waitersProvider(widget.cafeId)).valueOrNull ??
            const <Waiter>[])
        .where((w) => w.shopId == widget.shopId)
        .toList();
    final itemsAsync = ref.watch(itemsProvider(widget.cafeId));
    final items = itemsAsync.valueOrNull ?? const <Item>[];
    final byId = {for (final i in items) i.id: i};

    // Drop slip lines whose item was removed from the menu meanwhile.
    final lines = [
      for (final e in _qty.entries)
        if (byId[e.key] != null) SlipLine(byId[e.key]!, e.value),
    ];
    final waiter = waiters.where((w) => w.id == _waiterId).firstOrNull;

    final q = _search.trim().toLowerCase();
    final shown =
        q.isEmpty ? items : items.where((i) => i.name.toLowerCase().contains(q)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- waiter ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text('Waiter', style: theme.textTheme.titleSmall),
        ),
        SizedBox(
          height: 48,
          child: waiters.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No waiters in this shop yet. Ask the owner to add one.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: HColors.pencil)),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: waiters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final w = waiters[i];
                    final selected = w.id == _waiterId;
                    return ChoiceChip(
                      label: Text(w.name),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                          color: selected ? Colors.white : HColors.graphite),
                      onSelected: (_) => setState(() => _waiterId = w.id),
                    );
                  },
                ),
        ),

        // ---- menu ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Text('Menu', style: theme.textTheme.titleSmall),
              const SizedBox(width: 12),
              if (items.length > 8)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: const InputDecoration(
                        hintText: 'Find an item',
                        prefixIcon: Icon(Icons.search, size: 20),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: itemsAsync.isLoading && items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'The menu is empty. Ask the owner to add items.',
                            textAlign: TextAlign.center),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 170,
                        mainAxisExtent: 92,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _ItemTile(
                        item: shown[i],
                        qty: _qty[shown[i].id] ?? 0,
                        onTap: () => _add(shown[i]),
                      ),
                    ),
        ),

        // ---- the slip ----
        OrderSlip(
          lines: lines,
          waiterName: waiter?.name,
          busy: _busy,
          onChange: _change,
          onClear: () => setState(() => _qty.clear()),
          onPlace: waiter == null
              ? null
              : (total) => _place(waiter, lines, total),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.qty, required this.onTap});
  final Item item;
  final int qty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = qty > 0;
    return Semantics(
      button: true,
      label: '${item.name}, ${formatMoney(item.price)}${on ? ', $qty in order' : ''}. Tap to add one.',
      excludeSemantics: true,
      child: Material(
        color: on ? HColors.inkSoft : HColors.slip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: on ? HColors.ink : HColors.rule, width: on ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: on ? 30 : 0),
                      child: Text(item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(height: 1.2)),
                    ),
                    const Spacer(),
                    Text(formatMoney(item.price),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: on ? HColors.ink : HColors.pencil,
                            fontFeatures: tabular)),
                  ],
                ),
                if (on)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 26),
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: HColors.ink,
                          borderRadius: BorderRadius.circular(13)),
                      child: Text('$qty',
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white, fontFeatures: tabular)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
