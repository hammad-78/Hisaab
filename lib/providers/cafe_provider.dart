import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/item.dart';
import '../models/shop.dart';
import '../models/waiter.dart';
import '../services/cafe_service.dart';
import 'sales_provider.dart' show ShopRef;

final cafeServiceProvider = Provider<CafeService>((ref) => CafeService());

// autoDispose: when the screen using these goes away (e.g. on logout) the
// Firestore listener is dropped and the cached state is discarded. Without it,
// a permission error from a logout would be replayed after the next login.
final cafeNameProvider = StreamProvider.autoDispose.family<String, String>(
  (ref, cafeId) => ref.watch(cafeServiceProvider).cafeName(cafeId),
);

/// Every item / waiter in the cafe. Owner only (managers may read just their
/// own shop's, so they use the shop providers below).
final itemsProvider = StreamProvider.autoDispose.family<List<Item>, String>(
  (ref, cafeId) => ref.watch(cafeServiceProvider).items(cafeId),
);

final waitersProvider = StreamProvider.autoDispose.family<List<Waiter>, String>(
  (ref, cafeId) => ref.watch(cafeServiceProvider).waiters(cafeId),
);

/// One shop's menu and waiters (the manager's view).
final shopItemsProvider = StreamProvider.autoDispose
    .family<List<Item>, ShopRef>(
      (ref, s) => ref.watch(cafeServiceProvider).shopItems(s.cafeId, s.shopId),
    );

final shopWaitersProvider = StreamProvider.autoDispose
    .family<List<Waiter>, ShopRef>(
      (ref, s) =>
          ref.watch(cafeServiceProvider).shopWaiters(s.cafeId, s.shopId),
    );

final shopsProvider = StreamProvider.autoDispose.family<List<Shop>, String>(
  (ref, cafeId) => ref.watch(cafeServiceProvider).shops(cafeId),
);

/// Whether a shop is active (null while loading). Used to lock out a manager
/// whose shop the owner deactivated.
final managerShopActiveProvider = StreamProvider.autoDispose
    .family<bool, ShopRef>(
      (ref, s) =>
          ref.watch(cafeServiceProvider).shopActive(s.cafeId, s.shopId),
    );
