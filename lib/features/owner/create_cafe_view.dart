import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../models/app_user.dart';
import '../../providers/cafe_provider.dart';

/// Shown to a new owner who has no cafe yet.
class CreateCafeView extends ConsumerStatefulWidget {
  const CreateCafeView({super.key, required this.user});
  final AppUser user;

  @override
  ConsumerState<CreateCafeView> createState() => _CreateCafeViewState();
}

class _CreateCafeViewState extends ConsumerState<CreateCafeView> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = context.tr('Enter a cafe name'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(cafeServiceProvider)
          .createCafe(ownerUid: widget.user.uid, name: _name.text);
      // The profile stream updates and OwnerHome switches to the shop list.
    } catch (e) {
      if (mounted) {
        setState(() => _error = context.trf('Could not create cafe: {0}', [e]));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Create your cafe'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: context.tr('Cafe name')),
                onSubmitted: (_) => _create(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Create cafe')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
