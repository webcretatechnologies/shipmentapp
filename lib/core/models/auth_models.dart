/// Logged-in user as returned by `auth/login` and `auth/me`.
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.areaCode,
    this.capabilities = const Capabilities(),
    this.isSupplier = false,
    this.role = 'plantex',
  });

  final int id;
  final String name;
  final String email;
  final String? areaCode;
  final Capabilities capabilities;
  final bool isSupplier;
  final String role; // 'plantex' | 'supplier' (from the API)

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final isSupplier = json['is_supplier'] == true ||
        json['role']?.toString() == 'supplier' ||
        json['account_type']?.toString() == 'vendor';
    return AppUser(
      id: _int(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      areaCode: json['area_code']?.toString(),
      isSupplier: isSupplier,
      role: (json['role']?.toString().isNotEmpty == true)
          ? json['role'].toString()
          : (isSupplier ? 'supplier' : 'plantex'),
      capabilities: json['capabilities'] is Map
          ? Capabilities.fromJson(Map<String, dynamic>.from(json['capabilities']))
          : const Capabilities(),
    );
  }
}

/// Permission flags the backend returns alongside the user.
class Capabilities {
  const Capabilities({
    this.viewShipments = true,
    this.scan = true,
    this.kitting = false,
    this.boxScanning = false,
    this.racking = false,
    this.shortSku = false,
    this.shortBox = false,
  });

  final bool viewShipments;
  final bool scan;
  final bool kitting;
  final bool boxScanning;
  final bool racking;
  final bool shortSku;
  final bool shortBox;

  factory Capabilities.fromJson(Map<String, dynamic> json) => Capabilities(
        viewShipments: json['view_shipments'] != false,
        scan: json['scan'] != false,
        kitting: json['kitting'] == true,
        boxScanning: json['box_scanning'] == true,
        racking: json['racking'] == true,
        shortSku: json['short_sku'] == true,
        shortBox: json['short_box'] == true,
      );
}

/// Result of a successful login.
class AuthSession {
  AuthSession({required this.token, required this.user});
  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'])
        : <String, dynamic>{};
    // capabilities may sit at the top level of the login response
    if (json['capabilities'] is Map && userJson['capabilities'] == null) {
      userJson['capabilities'] = json['capabilities'];
    }
    return AuthSession(
      token: (json['token'] ?? '').toString(),
      user: AppUser.fromJson(userJson),
    );
  }
}

int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
