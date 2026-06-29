import 'package:flutter/material.dart';

/// The two login types / roles this single app supports.
/// Chosen at LOGIN time (Plantex tab vs Vendor tab) — not at build time.
enum AppRole { plantex, supplier }

/// Brand accent (same for both roles).
const Color kBrandAccent = Color(0xFF028894);

/// PWA design tokens (copied from public/pwa/warehouse-scan/app.css) so the
/// mobile app matches the warehouse PWA look exactly.
class Pwa {
  static const bg = Color(0xFFECF2F6);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const primary = Color(0xFF028894);
  static const primaryDark = Color(0xFF026E78);
  static const primaryMid = Color(0xFF03A0AD);
  static const primaryLight = Color(0xFFE5F5F6);
  static const primarySoft = Color(0xFFD7F2F4);
  static const primaryBorder = Color(0xFF9EDBDF);
  static const border = Color(0xFFD7E2EA);
  static const success = Color(0xFF50CD89);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFF1416C);
  static const radius = 14.0;

  /// The PWA teal header gradient (145deg from→mid→to).
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF026E78), Color(0xFF028894), Color(0xFF03A0AD)],
    stops: [0.0, 0.55, 1.0],
  );

  /// White → primary-light card gradient used for counters/cards in the PWA.
  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFE5F5F6)],
  );
}

extension AppRoleX on AppRole {
  bool get isSupplier => this == AppRole.supplier;

  String get title => isSupplier ? 'Plantex Vendor' : 'Plantex Warehouse';

  /// device_name sent to the API. 'warehouse-scan' triggers the warehouse
  /// permission gate (suppliers are rejected there); 'vendor-mobile' is the
  /// supplier flow.
  String get deviceName => isSupplier ? 'vendor-mobile' : 'warehouse-scan';

  /// Resolve the role the API reported for the logged-in user.
  static AppRole fromApi(String? role, {bool? isSupplier}) {
    if (isSupplier == true) return AppRole.supplier;
    return (role ?? '').toLowerCase() == 'supplier' ? AppRole.supplier : AppRole.plantex;
  }
}

/// Dashboard cards. `route` is the go_router path.
enum DashboardModule {
  shipments('All Shipments', Icons.local_shipping_outlined, '/shipments'),
  racking('Racking Area', Icons.grid_view_outlined, '/racking'),
  boxScanning('Box Scanning', Icons.inventory_2_outlined, '/box-scanning'),
  kitting('Kitting Process', Icons.dashboard_customize_outlined, '/kitting'),
  shortBox('Short Box', Icons.unarchive_outlined, '/short-box'),
  shortSku('Short SKU', Icons.report_problem_outlined, '/short-sku'),
  invoices('Invoices', Icons.receipt_long_outlined, '/invoices'),
  purchaseOrders('Purchase Orders', Icons.assignment_outlined, '/purchase-orders');

  const DashboardModule(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

/// Which cards each role sees.
List<DashboardModule> modulesForRole(AppRole role) {
  if (role == AppRole.supplier) {
    return const [
      DashboardModule.shipments,
      DashboardModule.boxScanning,
      DashboardModule.kitting,
      DashboardModule.shortBox,
      DashboardModule.shortSku,
      DashboardModule.invoices,
      DashboardModule.purchaseOrders,
    ];
  }
  // Plantex (warehouse)
  return const [
    DashboardModule.shipments,
    DashboardModule.racking,
    DashboardModule.boxScanning,
    DashboardModule.kitting,
    DashboardModule.shortBox,
    DashboardModule.shortSku,
  ];
}
