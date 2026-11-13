import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ).showSnackBar(const SnackBar(content: Text('Shop and manager created')));
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = e.code == 'email-already-in-use'
            ? 'That email is already used by another account.'
            : (e.message ?? 'Could not create manager.'),
      );
    } catch (e) {
      setState(() => _error = 'Could not create shop: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add shop')),
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
                    ? 'Enter a shop name'
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Manager login',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _managerName,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Manager name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the manager name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Manager email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: _dec('Password'),
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
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
                    : const Text('Create shop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
