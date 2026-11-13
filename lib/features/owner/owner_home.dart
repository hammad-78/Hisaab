import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cafe_provider.dart';
import 'add_shop_screen.dart';
import 'create_cafe_view.dart';
import 'reports_tab.dart';
import 'shops_tab.dart';

/// The owner sets up shops and their managers, and reads reports.
/// Menus and waiters belong to each shop's manager.
class OwnerHome extends ConsumerStatefulWidget {
  const OwnerHome({super.key, required this.user});
  final AppUser user;

  @override
  ConsumerState<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends ConsumerState<OwnerHome> {
  int _tab = 0; // 0 shops, 1 reports

  @override
  Widget build(BuildContext context) {
    final cafeId = widget.user.cafeId;
    final cafeName = cafeId == null
        ? null
        : ref.watch(cafeNameProvider(cafeId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(cafeName == null || cafeName.isEmpty ? 'Hisaab' : cafeName),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            color: context.h.khataRed,
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: cafeId == null
          ? CreateCafeView(user: widget.user)
          : _tab == 0
          ? ShopsTab(user: widget.user, cafeId: cafeId)
          : ReportsTab(cafeId: cafeId),
      floatingActionButton: cafeId == null || _tab != 0
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add_business),
              label: const Text('Add shop'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddShopScreen(cafeId: cafeId),
                ),
              ),
            ),
      bottomNavigationBar: cafeId == null
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.storefront),
                  label: 'Shops',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart),
                  label: 'Reports',
                ),
              ],
            ),
    );
  }
}
