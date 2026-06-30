import 'package:flutter/material.dart';

/// The two login types / roles this single app supports.
/// Chosen at LOGIN time (Plantex tab vs Vendor tab) — not at build time.
enum AppRole { plantex, supplier }

/// Brand accent — primary orange (same for both roles).
const Color kBrandAccent = Color(0xFFEA580C);

/// App design tokens. Orange brand + dark-navy headers, mirroring the mobile
/// app mockups.
class Pwa {
  static const bg = Color(0xFFF1F5F9);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  // ── Orange brand ──
  static const primary = Color(0xFFEA580C);
  static const primaryDark = Color(0xFFC2410C);
  static const primaryMid = Color(0xFFF97316);
  static const primaryLight = Color(0xFFFFF1E9);
  static const primarySoft = Color(0xFFFFE6D5);
  static const primaryBorder = Color(0xFFFED7AA);

  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
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

  /// Per-module accent used for the card icon tile + count badge.
  Color get accent {
    switch (this) {
      case DashboardModule.shipments:
        return const Color(0xFFEA580C); // orange
      case DashboardModule.racking:
        return const Color(0xFF3B82F6); // blue
      case DashboardModule.boxScanning:
        return const Color(0xFF22C55E); // green
      case DashboardModule.kitting:
        return const Color(0xFFF59E0B); // amber
      case DashboardModule.shortSku:
        return const Color(0xFFF59E0B); // amber
      case DashboardModule.shortBox:
        return const Color(0xFFF43F5E); // rose
      case DashboardModule.invoices:
        return const Color(0xFF3B82F6); // blue
      case DashboardModule.purchaseOrders:
        return const Color(0xFF8B5CF6); // purple
    }
  }
}

/// Which cards each role sees.
List<DashboardModule> modulesForRole(AppRole role) {
  if (role == AppRole.supplier) {
    return const [
      DashboardModule.shipments,
      DashboardModule.boxScanning,
      DashboardModule.kitting,
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
  ];
}
