enum UserRole { owner, manager }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? cafeId; // set for managers (and owners once a cafe exists)
  final String? shopId; // managers only

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.cafeId,
    this.shopId,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
    uid: uid,
    name: (m['name'] ?? '') as String,
    email: (m['email'] ?? '') as String,
    role: m['role'] == 'owner' ? UserRole.owner : UserRole.manager,
    cafeId: m['cafeId'] as String?,
    shopId: m['shopId'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'role': role.name,
    'cafeId': cafeId,
    'shopId': shopId,
  };
}
