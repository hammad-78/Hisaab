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
        title: Text(ctx.tr('Remove this order?')),
        content: Text(
          ctx.trf(
            '{0}, {1}. It will no longer count in today\'s sales or reports.',
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
            child: Text(ctx.tr('Remove order')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(salesServiceProvider).deleteOrder(cafeId, o);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(context.tr('Order removed'))),
        );
      }
    }
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
          final orders = SaleOrder.group(lines);
          final total = lines.fold<num>(0, (s, l) => s + l.total);
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
                child: orders.isEmpty
                    ? Center(
                        child: Text(
                          context.tr('No orders yet today.'),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          final o = orders[i];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            o.waiterName,
                                            style: theme.textTheme.titleSmall,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formatTime(o.createdAt),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
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
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatMoney(o.total),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontFeatures: tabular,
                                  ),
                                ),
                                IconButton(
                                  tooltip: context.tr('Remove order'),
                                  icon: const Icon(Icons.delete_outline),
                                  color: context.h.khataRed,
                                  onPressed: () => _remove(context, ref, o),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
