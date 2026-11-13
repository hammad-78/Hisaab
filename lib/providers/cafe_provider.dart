import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/item.dart';
import '../models/shop.dart';
import '../models/waiter.dart';
import '../services/cafe_service.dart';

final cafeServiceProvider = Provider<CafeService>((ref) => CafeService());

// autoDispose: when the screen using these goes away (e.g. on logout) the
// Firestore listener is dropped and the cached state is discarded. Without it,
// a permission error from a logout would be replayed after the next login.
final cafeNameProvider = StreamProvider.autoDispose.family<String, String>(
  (ref, cafeId) => ref.watch(cafeServiceProvider).cafeName(cafeId),
);

final itemsProvider = StreamProvider.autoDispose.family<List<Item>, String>(
  (ref, cafeId) => ref.watch(cafeServiceProvider).items(cafeId),
);

final waitersProvider = StreamProvider.autoDispose.family<List<Waiter>, String>(
  (ref, cafeId) => ref.watch(cafeServiceProvider).waiters(cafeId),
);

final shopsProvider = StreamProvider.autoDispose.family<List<Shop>, String>(
  (ref, cafeId) => ref.watch(cafeServiceProvider).shops(cafeId),
);
