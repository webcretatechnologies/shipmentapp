import 'package:flutter/material.dart';

/// The two login types / roles this single app supports.
/// Chosen at LOGIN time (Plantex tab vs Vendor tab) — not at build time.
enum AppRole { plantex, supplier }

/// Brand accent — primary teal (matches the PWA theme-color #028894).
const Color kBrandAccent = Color(0xFF028894);

/// App design tokens — mirror the PWA warehouse-scan look:
/// teal gradient header (#026e78 → #028894 → #03a0ad), light #ecf2f6 bg,
/// 14px cards with a #d7e2ea border.
class Pwa {
  static const bg = Color(0xFFECF2F6); // PWA body bg
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  // ── Teal brand (PWA #028894) ──
  static const primary = Color(0xFF028894);
  static const primaryDark = Color(0xFF026E78);
  static const primaryMid = Color(0xFF03A0AD);
  static const primaryLight = Color(0xFFE6F4F5);
  static const primarySoft = Color(0xFFCDEFF3);
  static const primaryBorder = Color(0xFF9BDFE7);

  static const border = Color(0xFFD7E2EA); // PWA card border
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF028894);
  static const radius = 14.0;

  // ── Teal gradient header (matches PWA .scan-app-back-bar) ──
  static const headerTop = Color(0xFF026E78);
  static const headerBottom = Color(0xFF03A0AD);
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF026E78), Color(0xFF028894), Color(0xFF03A0AD)],
    stops: [0.0, 0.55, 1.0],
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
  purchaseOrders('Purchase Orders', Icons.assignment_outlined, '/purchase-orders'),
  plantex('Plantex Shipments', Icons.factory_outlined, '/plantex-shipments');

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
      DashboardModule.plantex,
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
