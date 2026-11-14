import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/confirm_delete.dart';
import '../../core/widgets/list_heading.dart';
import '../../models/item.dart';
import '../../providers/cafe_provider.dart';

/// Add a new item to this shop's menu, or edit an existing one.
Future<void> showItemDialog(
  BuildContext context,
  WidgetRef ref, {
  required String cafeId,
  required String shopId,
  Item? existing,
}) {
  final name = TextEditingController(text: existing?.name);
  final price = TextEditingController(
    text: existing == null ? '' : formatPrice(existing.price),
  );
  final formKey = GlobalKey<FormState>();

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr(existing == null ? 'Add item' : 'Edit item')),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: ctx.tr('Item name')),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? ctx.tr('Enter a name') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: ctx.tr('Price'),
                prefixText: 'Rs ',
              ),
              validator: (v) {
                final n = num.tryParse((v ?? '').trim());
                return (n == null || n < 0)
                    ? ctx.tr('Enter a valid price')
                    : null;
              },
            ),
          ],
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
                .saveItem(
                  cafeId,
                  shopId: shopId,
                  id: existing?.id,
                  name: name.text,
                  price: num.parse(price.text.trim()),
                );
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(ctx.tr(existing == null ? 'Add item' : 'Save')),
        ),
      ],
    ),
  );
}

/// The manager's menu for their own shop.
class MenuTab extends ConsumerWidget {
  const MenuTab({super.key, required this.cafeId, required this.shopId});
  final String cafeId;
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      shopItemsProvider((cafeId: cafeId, shopId: shopId)),
    );
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(context.trf('The menu could not be loaded. {0}', [e])),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr(
                  'Your menu is empty.\nTap "Add item" to add what this shop sells.',
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
          itemBuilder: (_, index) {
            if (index == 0) {
              return ListHeading(
                title: 'Menu',
                count: list.length,
                one: 'item',
                many: 'items',
              );
            }
            final it = list[index - 1];
            return ListTile(
              key: ValueKey(it.id),
              leading: const Icon(Icons.coffee),
              title: Text(it.name),
              subtitle: Text(
                formatMoney(it.price),
                style: const TextStyle(fontFeatures: tabular),
              ),
              onTap: () => showItemDialog(
                context,
                ref,
                cafeId: cafeId,
                shopId: shopId,
                existing: it,
              ),
              trailing: IconButton(
                tooltip: context.trf('Delete {0}', [it.name]),
                icon: const Icon(Icons.delete_outline),
                color: context.h.khataRed,
                onPressed: () async {
                  if (await confirmDelete(context, it.name)) {
                    await ref
                        .read(cafeServiceProvider)
                        .deleteItem(cafeId, it.id);
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
