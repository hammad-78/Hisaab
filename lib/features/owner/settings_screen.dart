import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/theme_mode.dart';
import '../../models/shop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cafe_provider.dart';

/// Owner settings: per-shop edit / deactivate, and log out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.cafeId});
  final String cafeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(shopsProvider(cafeId));
    final shops = shopsAsync.valueOrNull ?? const <Shop>[];
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Settings'))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(context.tr('Appearance'), style: t.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(context.tr('Light')),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(context.tr('Dark')),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(context.tr('System')),
                      ),
                    ],
                    selected: {ref.watch(themeModeProvider)},
                    onSelectionChanged: (v) =>
                        ref.read(themeModeProvider.notifier).set(v.first),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(context.tr('Shops'), style: t.titleMedium),
              ),
              if (shopsAsync.isLoading && shops.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shops.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.tr('No shops yet.')),
                ),
              for (final s in shops) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: t.titleMedium),
                                Text(
                                  s.managerEmail,
                                  style: t.bodySmall?.copyWith(
                                    color: context.h.pencil,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!s.active)
                            Text(
                              context.tr('Inactive'),
                              style: t.bodyMedium?.copyWith(
                                color: context.h.khataRed,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editShop(context, ref, s),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(context.tr('Edit')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: s.active
                                  ? OutlinedButton.styleFrom(
                                      foregroundColor: context.h.khataRed,
                                    )
                                  : null,
                              onPressed: () => _toggleActive(context, ref, s),
                              icon: Icon(
                                s.active
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                              ),
                              label: Text(
                                context.tr(
                                  s.active ? 'Deactivate' : 'Activate',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: context.h.khataRed),
                title: Text(
                  context.tr('Log out'),
                  style: TextStyle(color: context.h.khataRed),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authServiceProvider).signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editShop(BuildContext context, WidgetRef ref, Shop shop) {
    final shopName = TextEditingController(text: shop.name);
    final managerName = TextEditingController(text: shop.managerName);
    final managerEmail = TextEditingController(text: shop.managerEmail);
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false;
    String? error;

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ctx.tr('Edit shop')),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: shopName,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: ctx.tr('Shop name')),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? ctx.tr('Enter a shop name')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: managerName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: ctx.tr('Manager name'),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? ctx.tr('Enter the manager name')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: managerEmail,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: ctx.tr('Manager email'),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      return (t.isEmpty || !t.contains('@'))
                          ? ctx.tr('Enter a valid email')
                          : null;
                    },
                  ),
                  if (managerEmail.text.trim().toLowerCase() !=
                      shop.managerEmail.toLowerCase()) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      decoration: InputDecoration(
                        labelText: ctx.tr('New manager password'),
                        helperText: ctx.tr(
                          'The current manager will be logged out. Give the new email and this password to the manager.',
                        ),
                        helperMaxLines: 3,
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? ctx.tr('At least 6 characters')
                          : null,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text(ctx.tr('Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(cafeServiceProvider)
                            .updateShop(
                              cafeId: cafeId,
                              shop: shop,
                              shopName: shopName.text,
                              managerName: managerName.text,
                              newEmail: managerEmail.text,
                              newPassword: password.text,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          setState(() {
                            busy = false;
                            error = ctx.trf('Could not save: {0}', [
                              e is FirebaseAuthException
                                  ? (e.message ?? e.code)
                                  : e,
                            ]);
                          });
                        }
                      }
                    },
              child: Text(ctx.tr('Save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    Shop shop,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final doneMsg = context.tr(
      shop.active ? 'Shop deactivated' : 'Shop activated',
    );
    if (shop.active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.trf('Deactivate shop {0}?', [shop.name])),
          content: Text(
            ctx.tr(
              'The manager will be logged out and cannot log in until you activate the shop again. All its data is kept.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ctx.h.khataRed,
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('Deactivate')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref
          .read(cafeServiceProvider)
          .setShopActive(cafeId, shop, !shop.active);
      messenger.showSnackBar(SnackBar(content: Text(doneMsg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
