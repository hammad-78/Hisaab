import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/shop.dart';
import '../../models/waiter.dart';
import '../../providers/cafe_provider.dart';
import 'menu_tab.dart' show confirmDelete;

Future<void> showWaiterDialog(
  BuildContext context,
  WidgetRef ref,
  String cafeId,
  List<Shop> shops, {
  Waiter? existing,
}) {
  final name = TextEditingController(text: existing?.name);
  String? shopId =
      existing?.shopId ?? (shops.length == 1 ? shops.first.id : null);
  final formKey = GlobalKey<FormState>();

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'Add waiter' : 'Edit waiter'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Waiter name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: shopId,
                decoration: const InputDecoration(labelText: 'Shop'),
                items: [
                  for (final s in shops)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => shopId = v),
                validator: (v) => v == null ? 'Choose a shop' : null,
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
                  .saveWaiter(
                    cafeId,
                    id: existing?.id,
                    name: name.text,
                    shopId: shopId!,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class WaitersTab extends ConsumerWidget {
  const WaitersTab({super.key, required this.cafeId});
  final String cafeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiters = ref.watch(waitersProvider(cafeId));
    final shops =
        ref.watch(shopsProvider(cafeId)).valueOrNull ?? const <Shop>[];
    final shopNames = {for (final s in shops) s.id: s.name};

    return waiters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load waiters: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No waiters yet.\nTap "Add waiter" to add one.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final w = list[i];
            return ListTile(
              key: ValueKey(w.id),
              leading: const Icon(Icons.person),
              title: Text(w.name),
              subtitle: Text(shopNames[w.shopId] ?? 'Unknown shop'),
              onTap: () =>
                  showWaiterDialog(context, ref, cafeId, shops, existing: w),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
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
