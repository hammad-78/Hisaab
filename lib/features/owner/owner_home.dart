import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/shop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cafe_provider.dart';
import 'add_shop_screen.dart';
import 'create_cafe_view.dart';
import 'menu_tab.dart';
import 'reports_tab.dart';
import 'shops_tab.dart';
import 'waiters_tab.dart';

class OwnerHome extends ConsumerStatefulWidget {
  const OwnerHome({super.key, required this.user});
  final AppUser user;

  @override
  ConsumerState<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends ConsumerState<OwnerHome> {
  int _tab = 0; // 0 shops, 1 menu, 2 waiters, 3 reports

  @override
  Widget build(BuildContext context) {
    final cafeId = widget.user.cafeId;
    final cafeName =
        cafeId == null ? null : ref.watch(cafeNameProvider(cafeId)).valueOrNull;
    // Keep the shops stream alive on every tab (the waiter form needs it).
    if (cafeId != null) ref.watch(shopsProvider(cafeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(cafeName == null || cafeName.isEmpty ? 'Hisaab' : cafeName),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: cafeId == null
          ? CreateCafeView(user: widget.user)
          : switch (_tab) {
              0 => ShopsTab(user: widget.user, cafeId: cafeId),
              1 => MenuTab(cafeId: cafeId),
              2 => WaitersTab(cafeId: cafeId),
              _ => ReportsTab(cafeId: cafeId),
            },
      floatingActionButton: cafeId == null ? null : _fab(cafeId),
      bottomNavigationBar: cafeId == null
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.storefront), label: 'Shops'),
                NavigationDestination(icon: Icon(Icons.coffee), label: 'Menu'),
                NavigationDestination(
                    icon: Icon(Icons.person), label: 'Waiters'),
                NavigationDestination(
                    icon: Icon(Icons.bar_chart), label: 'Reports'),
              ],
            ),
    );
  }

  Widget? _fab(String cafeId) {
    switch (_tab) {
      case 3:
        return null; // reports have their own export buttons
      case 0:
        return FloatingActionButton.extended(
          icon: const Icon(Icons.add_business),
          label: const Text('Add shop'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddShopScreen(cafeId: cafeId))),
        );
      case 1:
        return FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
          onPressed: () => showItemDialog(context, ref, cafeId),
        );
      case 2:
        return FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: const Text('Add waiter'),
          onPressed: () {
            final shops =
                ref.read(shopsProvider(cafeId)).valueOrNull ?? const <Shop>[];
            if (shops.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Create a shop first, then add waiters.')));
              return;
            }
            showWaiterDialog(context, ref, cafeId, shops);
          },
        );
      default:
        return null;
    }
  }
}
