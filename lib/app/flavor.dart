import 'package:flutter/material.dart';

/// The two login types / roles this single app supports.
/// Chosen at LOGIN time (Plantex tab vs Vendor tab) — not at build time.
enum AppRole { plantex, supplier }

/// Brand accent — primary teal (same for both roles).
const Color kBrandAccent = Color(0xFF0FAFBF);

/// App design tokens. Teal brand (#0FAFBF) + dark-navy headers.
class Pwa {
  static const bg = Color(0xFFF1F5F9);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  // ── Teal brand (#0FAFBF) ──
  static const primary = Color(0xFF0FAFBF);
  static const primaryDark = Color(0xFF0C8E9C);
  static const primaryMid = Color(0xFF2BC4D4);
  static const primaryLight = Color(0xFFE6F8FA);
  static const primarySoft = Color(0xFFCDEFF3);
  static const primaryBorder = Color(0xFF9BDFE7);

  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0C8E9C);
  static const radius = 14.0;

  // ── Dark navy header ──
  static const headerTop = Color(0xFF1E293B);
  static const headerBottom = Color(0xFF0F172A);
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF243248), Color(0xFF111B2B)],
  );

  /// White → faint-grey card gradient used for counters/scan areas.
  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
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

  /// Per-module accent — single teal brand (#0FAFBF) for all cards.
  Color get accent => const Color(0xFF0FAFBF);
}

/// Which cards each role sees.
List<DashboardModule> modulesForRole(AppRole role) {
  if (role == AppRole.supplier) {
    return const [
      DashboardModule.shipments,
      DashboardModule.racking,
      DashboardModule.boxScanning,
      DashboardModule.kitting,
      DashboardModule.shortSku,
      DashboardModule.shortBox,
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
    DashboardModule.shortSku,
    DashboardModule.shortBox,
  ];
}
