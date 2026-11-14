import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/confirm_delete.dart';
import '../../core/widgets/list_heading.dart';
import '../../models/waiter.dart';
import '../../providers/cafe_provider.dart';

/// Add a waiter to this shop, or rename one.
Future<void> showWaiterDialog(
  BuildContext context,
  WidgetRef ref, {
  required String cafeId,
  required String shopId,
  Waiter? existing,
}) {
  final name = TextEditingController(text: existing?.name);
  final formKey = GlobalKey<FormState>();

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr(existing == null ? 'Add waiter' : 'Rename waiter')),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: ctx.tr('Waiter name')),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? ctx.tr('Enter a name') : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.tr('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            await ref
                .read(cafeServiceProvider)
                .saveWaiter(
                  cafeId,
                  shopId: shopId,
                  id: existing?.id,
                  name: name.text,
                );
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(ctx.tr(existing == null ? 'Add waiter' : 'Save')),
        ),
      ],
    ),
  );
}

/// The manager's waiters for their own shop.
class WaitersTab extends ConsumerWidget {
  const WaitersTab({super.key, required this.cafeId, required this.shopId});
  final String cafeId;
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiters = ref.watch(
      shopWaitersProvider((cafeId: cafeId, shopId: shopId)),
    );
    return waiters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(context.trf('Waiters could not be loaded. {0}', [e])),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr(
                  'No waiters yet.\nTap "Add waiter" to add the people who take orders.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            if (i == 0) {
              return ListHeading(
                title: 'Waiters',
                count: list.length,
                one: 'waiter',
                many: 'waiters',
              );
            }
            final w = list[i - 1];
            return ListTile(
              key: ValueKey(w.id),
              leading: const Icon(Icons.person),
              title: Text(w.name),
              onTap: () => showWaiterDialog(
                context,
                ref,
                cafeId: cafeId,
                shopId: shopId,
                existing: w,
              ),
              trailing: IconButton(
                tooltip: context.trf('Delete {0}', [w.name]),
                icon: const Icon(Icons.delete_outline),
                color: context.h.khataRed,
                onPressed: () async {
                  if (await confirmDelete(context, w.name)) {
                    await ref
                        .read(cafeServiceProvider)
                        .deleteWaiter(cafeId, w.id);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
