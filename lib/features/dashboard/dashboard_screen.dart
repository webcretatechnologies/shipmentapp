import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/dashboard_counts.dart';
import '../../core/widgets/app_ui.dart';

/// A card is shown only if the logged-in user has access to that module —
/// mirroring their admin-panel permissions (scan-only user sees only scanning,
/// racking access → racking, short-sku access → short-sku, etc.).
bool _hasAccess(DashboardModule m, Capabilities c, bool isSupplier) {
  switch (m) {
    case DashboardModule.shipments:
      return c.viewShipments || c.scan;
    case DashboardModule.racking:
      return c.racking;
    case DashboardModule.boxScanning:
      return c.boxScanning;
    case DashboardModule.kitting:
      return c.kitting;
    case DashboardModule.shortSku:
      return c.shortSku;
    case DashboardModule.shortBox:
      return c.shortBox;
    case DashboardModule.invoices:
    case DashboardModule.purchaseOrders:
      return isSupplier; // vendor-only modules
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardCounts> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardCounts> _load() async {
    final api = context.read<ApiClient>();
    try {
      final data = await api.get(ApiEndpoints.dashboardCounts);
      if (data is Map) return DashboardCounts.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      // counts are optional — cards still render with 0
    }
    return DashboardCounts();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final role = auth.role;
    final caps = auth.user?.capabilities ?? const Capabilities();
    // Only the modules this user actually has access to (same as admin permissions).
    final modules = modulesForRole(role)
        .where((m) => _hasAccess(m, caps, role.isSupplier))
        .toList();

    return Scaffold(
      body: FutureBuilder<DashboardCounts>(
        future: _future,
        builder: (context, snap) {
          final counts = snap.data ?? DashboardCounts();
          return Column(
            children: [
              DarkHeader(
                overline: role.isSupplier ? 'Vendor Portal' : 'Plantex Warehouse',
                title: 'Dashboard',
                trailing: DarkIconButton(
                  icon: Icons.logout,
                  tooltip: 'Logout',
                  onTap: auth.logout,
                ),
                child: StatStrip(items: [
                  StatItem('${counts.active}', 'Active', const Color(0xFF2BC4D4)),
                  StatItem('${counts.complete}', 'Complete', const Color(0xFF22C55E)),
                  StatItem('${counts.pending}', 'Pending', const Color(0xFFF59E0B)),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: modules.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No modules are assigned to your account.\nAsk an admin to grant access.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ),
                        ])
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                          children: [
                            const SectionLabel('Quick Access'),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1.05,
                              children: modules
                                  .map((m) => _ModuleCard(
                                        module: m,
                                        count: counts.forModule(m.name),
                                        onTap: () => context.push(m.route),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.count, required this.onTap});

  final DashboardModule module;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = module.accent;
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: accent),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$count',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
            ],
          ),
          const Spacer(),
          Text(module.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Tap to open', style: TextStyle(color: Colors.black45, fontSize: 12)),
        ],
      ),
    );
  }
}
