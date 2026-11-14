import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cafe_provider.dart';
import 'add_shop_screen.dart';
import 'create_cafe_view.dart';
import 'reports_tab.dart';
import 'settings_screen.dart';
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
          const LanguageButton(),
          if (cafeId != null)
            IconButton(
              tooltip: context.tr('Settings'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(cafeId: cafeId),
                ),
              ),
            )
          else
            IconButton(
              tooltip: context.tr('Log out'),
              icon: const Icon(Icons.logout),
              color: context.h.khataRed,
              onPressed: () => ref.read(authServiceProvider).signOut(),
            ),
        ],
      ),
      body: cafeId == null
          ? CreateCafeView(user: widget.user)
          : LayoutBuilder(
              builder: (context, c) {
                final content = _tab == 0
                    ? ShopsTab(user: widget.user, cafeId: cafeId)
                    : ReportsTab(cafeId: cafeId);
                if (c.maxWidth < 840) return content;
                // Wide screens (web, tablet): side rail, content kept readable.
                return Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _tab,
                      onDestinationSelected: (i) => setState(() => _tab = i),
                      backgroundColor: context.h.slip,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Icons.storefront_outlined),
                          selectedIcon: const Icon(Icons.storefront),
                          label: Text(context.tr('Shops')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.bar_chart_outlined),
                          selectedIcon: const Icon(Icons.bar_chart),
                          label: Text(context.tr('Reports')),
                        ),
                      ],
                    ),
                    VerticalDivider(width: 1, color: context.h.rule),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 880),
                          child: content,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: cafeId == null || _tab != 0
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add_business),
              label: Text(context.tr('Add shop')),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddShopScreen(cafeId: cafeId),
                ),
              ),
            ),
      bottomNavigationBar:
          cafeId == null || MediaQuery.sizeOf(context).width >= 840
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.storefront),
                  label: context.tr('Shops'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bar_chart),
                  label: context.tr('Reports'),
                ),
              ],
            ),
    );
  }
}
