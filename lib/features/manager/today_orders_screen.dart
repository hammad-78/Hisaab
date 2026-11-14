import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/sale.dart';
import '../../providers/sales_provider.dart';

class TodayOrdersScreen extends ConsumerWidget {
  const TodayOrdersScreen({
    super.key,
    required this.cafeId,
    required this.shopId,
  });
  final String cafeId;
  final String shopId;

  Future<void> _remove(BuildContext context, WidgetRef ref, SaleOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Cancel this order?')),
        content: Text(
          ctx.trf(
            '{0}, {1}. It will no longer count in today\'s sales or reports. You can revive it later.',
            [o.waiterName, formatMoney(o.total)],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Keep order')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.h.khataRed,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('Cancel order')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(salesServiceProvider)
          .setOrderCancelled(cafeId, o, cancelled: true);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('Order cancelled'))));
      }
    }
  }

  Future<void> _revive(BuildContext context, WidgetRef ref, SaleOrder o) async {
    await ref
        .read(salesServiceProvider)
        .setOrderCancelled(cafeId, o, cancelled: false);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Order revived'))));
    }
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    SaleOrder o, {
    required bool cancelled,
  }) {
    final theme = Theme.of(context);
    final muted = cancelled ? context.h.pencil : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      o.waiterName,
                      style: theme.textTheme.titleSmall?.copyWith(color: muted),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatTime(o.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.h.pencil,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final l in o.lines)
                  Text(
                    '${l.qty} x ${l.itemName}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
              ],
            ),
          ),
          Text(
            formatMoney(o.total),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: tabular,
              color: muted,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          if (cancelled)
            TextButton(
              onPressed: () => _revive(context, ref, o),
              child: Text(context.tr('Revive')),
            )
          else
            IconButton(
              tooltip: context.tr('Cancel order'),
              icon: const Icon(Icons.cancel_outlined),
              color: context.h.khataRed,
              onPressed: () => _remove(context, ref, o),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sales = ref.watch(
      todaySalesProvider((cafeId: cafeId, shopId: shopId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("Today's orders")),
        actions: const [LanguageButton()],
      ),
      body: sales.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.trf('Today\'s orders could not be loaded. {0}', [e]),
            ),
          ),
        ),
        data: (lines) {
          final all = SaleOrder.group(lines);
          final orders = all.where((o) => !o.cancelled).toList();
          final cancelled = all.where((o) => o.cancelled).toList();
          final total = orders.fold<num>(0, (s, o) => s + o.total);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: context.h.slip,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        orders.length == 1
                            ? context.tr('1 order so far')
                            : context.trf('{0} orders so far', [orders.length]),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.h.pencil,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(total),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: context.h.ink,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: all.isEmpty
                    ? Center(
                        child: Text(
                          context.tr('No orders yet today.'),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(
                        children: [
                          for (final o in orders) ...[
                            _row(context, ref, o, cancelled: false),
                            const Divider(),
                          ],
                          if (cancelled.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Text(
                                context.trf('Cancelled orders ({0})', [
                                  cancelled.length,
                                ]),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: context.h.pencil,
                                ),
                              ),
                            ),
                            const Divider(),
                            for (final o in cancelled) ...[
                              _row(context, ref, o, cancelled: true),
                              const Divider(),
                            ],
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
