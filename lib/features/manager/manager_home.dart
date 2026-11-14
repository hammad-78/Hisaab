import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/item.dart';
import '../../models/waiter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cafe_provider.dart';
import '../../providers/sales_provider.dart';
import 'menu_tab.dart';
import 'today_orders_screen.dart';
import 'waiters_tab.dart';
import 'widgets/order_slip.dart';

/// The manager's portal: the counter for taking orders, plus this shop's
/// menu and waiters, which the manager looks after.
class ManagerHome extends ConsumerStatefulWidget {
  const ManagerHome({super.key, required this.user});
  final AppUser user;

  @override
  ConsumerState<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends ConsumerState<ManagerHome> {
  int _tab = 0; // 0 counter, 1 menu, 2 waiters

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final cafeId = user.cafeId;
    final shopId = user.shopId;

    if (cafeId == null || shopId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Hisaab'),
          actions: [const LanguageButton(), _logout(ref)],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr(
                'This login is not linked to a shop. Ask the cafe owner to add you as a shop manager.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final shops = ref.watch(shopsProvider(cafeId)).valueOrNull ?? const [];
    final shopName =
        shops.where((s) => s.id == shopId).map((s) => s.name).firstOrNull ?? '';
    final today = ref.watch(
      todaySalesProvider((cafeId: cafeId, shopId: shopId)),
    );
    final todayOrders = today.valueOrNull?.map((s) => s.orderId).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(shopName),
        actions: [
          const LanguageButton(),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TodayOrdersScreen(cafeId: cafeId, shopId: shopId),
              ),
            ),
            icon: const Icon(Icons.receipt_long),
            label: Text(
              todayOrders == null
                  ? context.tr('Today')
                  : context.trf('Today ({0})', [todayOrders]),
            ),
          ),
          _logout(ref),
        ],
      ),
      // IndexedStack keeps the counter alive, so a half-built order survives
      // a quick trip to the Menu tab.
      body: IndexedStack(
        index: _tab,
        children: [
          _Counter(
            user: user,
            cafeId: cafeId,
            shopId: shopId,
            onOpenTab: (i) => setState(() => _tab = i),
          ),
          MenuTab(cafeId: cafeId, shopId: shopId),
          WaitersTab(cafeId: cafeId, shopId: shopId),
        ],
      ),
      floatingActionButton: switch (_tab) {
        1 => FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: Text(context.tr('Add item')),
          onPressed: () =>
              showItemDialog(context, ref, cafeId: cafeId, shopId: shopId),
        ),
        2 => FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: Text(context.tr('Add waiter')),
          onPressed: () =>
              showWaiterDialog(context, ref, cafeId: cafeId, shopId: shopId),
        ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.point_of_sale),
            label: context.tr('Counter'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.coffee),
            label: context.tr('Menu'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person),
            label: context.tr('Waiters'),
          ),
        ],
      ),
    );
  }

  Widget _logout(WidgetRef ref) => IconButton(
    tooltip: context.tr('Log out'),
    icon: const Icon(Icons.logout),
    color: HTokens.light.khataRed,
    onPressed: () => ref.read(authServiceProvider).signOut(),
  );
}

/// The counter: pick a waiter, tap menu items to build the slip, place it.
class _Counter extends ConsumerStatefulWidget {
  const _Counter({
    required this.user,
    required this.cafeId,
    required this.shopId,
    required this.onOpenTab,
  });
  final AppUser user;
  final String cafeId;
  final String shopId;

  /// Jumps to the Menu (1) or Waiters (2) tab from an empty state.
  final void Function(int tab) onOpenTab;

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
      await ref
          .read(salesServiceProvider)
          .addOrder(
            cafeId: widget.cafeId,
            shopId: widget.shopId,
            managerUid: widget.user.uid,
            waiter: waiter,
            lines: [for (final l in lines) (item: l.item, qty: l.qty)],
          );
      if (!mounted) return;
      setState(() => _qty.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.trf('Order placed for {0}: {1}', [
              waiter.name,
              formatMoney(total),
            ]),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.trf(
                'Order not saved. Check your connection and try again. ({0})',
                [e],
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shopRef = (cafeId: widget.cafeId, shopId: widget.shopId);
    final waiters =
        ref.watch(shopWaitersProvider(shopRef)).valueOrNull ?? const <Waiter>[];
    final itemsAsync = ref.watch(shopItemsProvider(shopRef));
    final items = itemsAsync.valueOrNull ?? const <Item>[];
    final byId = {for (final i in items) i.id: i};

    // Drop slip lines whose item was removed from the menu meanwhile.
    final lines = [
      for (final e in _qty.entries)
        if (byId[e.key] != null) SlipLine(byId[e.key]!, e.value),
    ];
    final waiter = waiters.where((w) => w.id == _waiterId).firstOrNull;

    final q = _search.trim().toLowerCase();
    final shown = q.isEmpty
        ? items
        : items.where((i) => i.name.toLowerCase().contains(q)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- waiter ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(context.tr('Waiter'), style: theme.textTheme.titleSmall),
        ),
        SizedBox(
          height: 48,
          child: waiters.isEmpty
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton.icon(
                      onPressed: () => widget.onOpenTab(2),
                      icon: const Icon(Icons.person_add),
                      label: Text(context.tr('No waiters yet. Add waiters')),
                    ),
                  ),
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
                        color: selected ? context.h.onInk : context.h.graphite,
                      ),
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
              Text(context.tr('Menu'), style: theme.textTheme.titleSmall),
              const SizedBox(width: 12),
              if (items.length > 8)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: context.tr('Find an item'),
                        prefixIcon: const Icon(Icons.search, size: 20),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr(
                            'Your menu is empty. Add what this shop sells to start taking orders.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => widget.onOpenTab(1),
                          icon: const Icon(Icons.add),
                          label: Text(context.tr('Add menu items')),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    // Grow with the phone's text size so names never clip.
                    mainAxisExtent:
                        92 * (MediaQuery.textScalerOf(context).scale(16) / 16),
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
      label: context.trf('{0}, {1}. Tap to add one.', [
        item.name,
        formatMoney(item.price) +
            (on ? ', ${context.trf('{0} in order', [qty])}' : ''),
      ]),
      excludeSemantics: true,
      child: Material(
        color: on ? context.h.inkSoft : context.h.slip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: on ? context.h.ink : context.h.rule,
            width: on ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            // Name gets the full width; the count badge sits beside the
            // price so it never squeezes the name at large text sizes.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.2),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          formatMoney(item.price),
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: on ? context.h.ink : context.h.pencil,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                    ),
                    if (on)
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.h.ink,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '$qty',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: context.h.onInk,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
