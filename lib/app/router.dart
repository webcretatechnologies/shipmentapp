import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/shipments/shipments_list_screen.dart';
import '../features/shipments/shipment_scan_screen.dart';
import '../features/operations/racking_box_screen.dart';
import '../features/kitting/kitting_screen.dart';
import '../features/short_sku/short_sku_screen.dart';
import '../features/short_box/short_box_screen.dart';
import '../features/supplier/supplier_invoice_screen.dart';
import '../features/supplier/purchase_orders_screen.dart';
import '../features/plantex/plantex_list_screen.dart';
import '../features/plantex/plantex_scan_screen.dart';
import '../features/plantex/plantex_invoice_screen.dart';

GoRouter buildRouter(AuthController auth) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      switch (auth.status) {
        case AuthStatus.unknown:
          return null; // splash handled by app while restoring
        case AuthStatus.unauthenticated:
          return loggingIn ? null : '/login';
        case AuthStatus.authenticated:
          return loggingIn ? '/dashboard' : null;
      }
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/shipments', builder: (_, __) => const ShipmentsListScreen()),
      GoRoute(
        path: '/shipments/:id/scan',
        builder: (_, s) => ShipmentScanScreen(
          shipmentId: int.parse(s.pathParameters['id']!),
          shipmentCode: s.uri.queryParameters['code'] ?? '',
        ),
      ),
      // Racking + Box Scanning share one tabbed screen; each card opens its tab.
      GoRoute(path: '/racking', builder: (_, __) => const RackingBoxScreen(initialTab: 0)),
      GoRoute(path: '/box-scanning', builder: (_, __) => const RackingBoxScreen(initialTab: 1)),
      GoRoute(path: '/kitting', builder: (_, __) => const KittingScreen()),
      GoRoute(
        path: '/short-sku',
        builder: (_, s) => ShortSkuScreen(shipmentId: int.tryParse(s.uri.queryParameters['shipment'] ?? '')),
      ),
      GoRoute(
        path: '/short-box',
        builder: (_, s) => ShortBoxScreen(shipmentId: int.tryParse(s.uri.queryParameters['shipment'] ?? '')),
      ),
      GoRoute(path: '/invoices', builder: (_, __) => const SupplierInvoiceScreen()),
      GoRoute(path: '/purchase-orders', builder: (_, __) => const PurchaseOrdersScreen()),
      // Plantex (PO-based vendor) flow: list → scan/pack → raise invoice.
      GoRoute(path: '/plantex-shipments', builder: (_, __) => const PlantexListScreen()),
      GoRoute(
        path: '/plantex-shipments/:id',
        builder: (_, s) => PlantexScanScreen(id: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/plantex-shipments/:id/invoice',
        builder: (_, s) => PlantexInvoiceScreen(id: int.parse(s.pathParameters['id']!)),
      ),
    ],
    errorBuilder: (_, s) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('No route for ${s.uri}')),
    ),
  );
}

/// Convenience accessor.
AuthController authOf(BuildContext context) => context.read<AuthController>();
