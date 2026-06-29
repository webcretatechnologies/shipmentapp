import 'package:flutter/material.dart';

/// The two apps this single codebase produces.
enum AppFlavor { shipment, supplier }

/// Per-flavor configuration: title, brand accent, default API host, and which
/// dashboard modules are exposed. Selected at compile time via
/// `--dart-define=APP_FLAVOR=shipment|supplier`.
class FlavorConfig {
  const FlavorConfig({
    required this.flavor,
    required this.appTitle,
    required this.accent,
    required this.defaultBaseUrl,
    required this.modules,
  });

  final AppFlavor flavor;
  final String appTitle;
  final Color accent;
  final String defaultBaseUrl;
  final List<DashboardModule> modules;

  bool get isSupplier => flavor == AppFlavor.supplier;

  static FlavorConfig of(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.supplier:
        return const FlavorConfig(
          flavor: AppFlavor.supplier,
          appTitle: 'Plantex Vendor',
          accent: Color(0xFF028894),
          defaultBaseUrl: 'https://supplier.plantex.work',
          modules: [
            DashboardModule.shipments,
            DashboardModule.boxScanning,
            DashboardModule.shortSku,
            DashboardModule.shortBox,
            DashboardModule.kitting,
            DashboardModule.invoices,
            DashboardModule.purchaseOrders,
          ],
        );
      case AppFlavor.shipment:
        return const FlavorConfig(
          flavor: AppFlavor.shipment,
          appTitle: 'Plantex Warehouse',
          accent: Color(0xFF028894),
          defaultBaseUrl: 'https://plantex.work',
          modules: [
            DashboardModule.shipments,
            DashboardModule.racking,
            DashboardModule.boxScanning,
            DashboardModule.shortSku,
            DashboardModule.shortBox,
            DashboardModule.kitting,
          ],
        );
    }
  }

  static AppFlavor parse(String raw) =>
      raw.toLowerCase() == 'supplier' ? AppFlavor.supplier : AppFlavor.shipment;
}

/// Dashboard cards (spec section 2). `route` is the go_router path.
enum DashboardModule {
  shipments('All Shipments', Icons.local_shipping_outlined, '/shipments'),
  racking('Racking Area', Icons.grid_view_outlined, '/racking'),
  boxScanning('Box Scanning', Icons.inventory_2_outlined, '/box-scanning'),
  shortSku('Short SKU Requests', Icons.report_problem_outlined, '/short-sku'),
  shortBox('Short Box Requests', Icons.unarchive_outlined, '/short-box'),
  kitting('Kitting Process', Icons.dashboard_customize_outlined, '/kitting'),
  invoices('Invoices', Icons.receipt_long_outlined, '/invoices'),
  purchaseOrders('Purchase Orders', Icons.assignment_outlined, '/purchase-orders');

  const DashboardModule(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
