import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../providers/cafe_provider.dart';

class AddShopScreen extends ConsumerStatefulWidget {
  const AddShopScreen({super.key, required this.cafeId});
  final String cafeId;

  @override
  ConsumerState<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends ConsumerState<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _managerName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _shopName.dispose();
    _managerName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(cafeServiceProvider)
          .createShopWithManager(
            cafeId: widget.cafeId,
            shopName: _shopName.text,
            managerName: _managerName.text,
            managerEmail: _email.text,
            managerPassword: _password.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(context.tr('Shop and manager created'))),
      );
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = e.code == 'email-already-in-use'
            ? context.tr('That email is already used by another account.')
            : (e.message ?? context.tr('Could not create manager.')),
      );
    } catch (e) {
      setState(
        () => _error = context.trf('Could not create shop: {0}', [e]),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: context.tr(label));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Add shop')),
        actions: const [LanguageButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _shopName,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Shop name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('Enter a shop name')
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('Manager login'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _managerName,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Manager name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('Enter the manager name')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Manager email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? context.tr('Enter a valid email')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: _dec('Password'),
                validator: (v) => (v == null || v.length < 6)
                    ? context.tr('At least 6 characters')
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Create shop')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
