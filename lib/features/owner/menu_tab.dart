import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/item.dart';
import '../../providers/cafe_provider.dart';

Future<void> showItemDialog(
  BuildContext context,
  WidgetRef ref,
  String cafeId, {
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
      title: Text(existing == null ? 'Add item' : 'Edit item'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            TextFormField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Price'),
              validator: (v) {
                final n = num.tryParse((v ?? '').trim());
                return (n == null || n < 0) ? 'Enter a valid price' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            await ref
                .read(cafeServiceProvider)
                .saveItem(
                  cafeId,
                  id: existing?.id,
                  name: name.text,
                  price: num.parse(price.text.trim()),
                );
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $what?'),
      content: const Text('Past sales are not affected.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class MenuTab extends ConsumerWidget {
  const MenuTab({super.key, required this.cafeId});
  final String cafeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider(cafeId));
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load items: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No items yet.\nTap "Add item" to build your menu.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final it = list[i];
            return ListTile(
              key: ValueKey(it.id),
              leading: const Icon(Icons.coffee),
              title: Text(it.name),
              subtitle: Text(
                formatMoney(it.price),
                style: const TextStyle(fontFeatures: tabular),
              ),
              onTap: () => showItemDialog(context, ref, cafeId, existing: it),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
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
