import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/models/dashboard_counts.dart';
import '../../core/widgets/app_bottom_nav.dart';

/// Home — "Supplier Portal" module grid (mockup 02). Cards navigate into the
/// existing flows; all logic/counts come from the same admin-panel operations.
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
    } catch (_) {/* counts optional */}
    return DashboardCounts();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final vendorName = (user?.name ?? 'Vendor').trim();
    final initials = vendorName.isNotEmpty ? vendorName[0].toUpperCase() : 'V';

    return Scaffold(
      backgroundColor: Pwa.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<DashboardCounts>(
          future: _future,
          builder: (context, snap) {
            final c = snap.data ?? DashboardCounts();
            final modules = _modules(c);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Row(
                      children: [
                        _circle(initials, onTap: () {}),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text('Supplier Portal',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Pwa.text)),
                        ),
                        _circleIcon(Icons.logout_rounded, onTap: () => context.read<AuthController>().logout()),
                      ],
                    ),
                  ),
                  // Teal welcome banner
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(gradient: Pwa.headerGradient),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, $vendorName',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Select a module to get started',
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                      ],
                    ),
                  ),
                  // Module grid
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.86,
                      children: modules.map((m) => _ModuleCard(m)).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 0),
    );
  }

  List<_Module> _modules(DashboardCounts c) => [
        _Module('FBA Shipment', 'Amazon FBA inbound shipments', Icons.local_shipping_outlined,
            const Color(0xFFE6F4F5), Pwa.primaryDark, '${c.shipments} Active', Pwa.primaryDark, const Color(0xFFE6F4F5), '/shipments'),
        _Module('Plantex Shipment', 'Direct Plantex warehouse orders', Icons.inventory_2_outlined,
            const Color(0xFFEDE9FE), const Color(0xFF7C3AED), '${c.shipments} Active', const Color(0xFF7C3AED), const Color(0xFFEDE9FE), '/shipments'),
        _Module('Kitting for FBA', 'Combo SKU assembly & kitting', Icons.edit_outlined,
            const Color(0xFFFEF3C7), const Color(0xFFD97706), '${c.kitting} Pending', const Color(0xFFB45309), const Color(0xFFFEF3C7), '/kitting'),
        _Module('Invoice — FBA', 'Raise FBA shipment invoices', Icons.description_outlined,
            const Color(0xFFDCFCE7), const Color(0xFF16A34A), '${c.invoices} Due', const Color(0xFF15803D), const Color(0xFFDCFCE7), '/invoices'),
        _Module('Invoice — Plantex', 'Raise Plantex shipment invoices', Icons.description_outlined,
            const Color(0xFFFEE2E2), const Color(0xFFDC2626), '${c.invoices} Due', const Color(0xFFB91C1C), const Color(0xFFFEE2E2), '/invoices'),
        _Module('Box & Racking — FBA', 'Scan boxes & assign rack locations', Icons.dns_outlined,
            const Color(0xFFCDEFF3), Pwa.primaryDark, '${c.boxScanning} Boxes', Pwa.primaryDark, const Color(0xFFCDEFF3), '/racking'),
      ];

  Widget _circle(String txt, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: CircleAvatar(radius: 18, backgroundColor: const Color(0xFFCBD5E1), child: Text(txt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      );
  Widget _circleIcon(IconData icon, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: CircleAvatar(radius: 18, backgroundColor: const Color(0xFFE2E8F0), child: Icon(icon, size: 18, color: Pwa.muted)),
      );
}

class _Module {
  const _Module(this.title, this.subtitle, this.icon, this.iconBg, this.iconColor, this.pill, this.pillColor, this.pillBg, this.route);
  final String title, subtitle, pill, route;
  final IconData icon;
  final Color iconBg, iconColor, pillColor, pillBg;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard(this.m);
  final _Module m;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(m.route),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Pwa.border),
            boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 14, offset: Offset(0, 6))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: m.iconBg, borderRadius: BorderRadius.circular(13)),
                child: Icon(m.icon, color: m.iconColor, size: 24),
              ),
              const SizedBox(height: 14),
              Text(m.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Pwa.text)),
              const SizedBox(height: 4),
              Text(m.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pwa.muted, fontSize: 12, height: 1.3)),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: m.pillBg, borderRadius: BorderRadius.circular(999)),
                    child: Text(m.pill, style: TextStyle(color: m.pillColor, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: Pwa.muted, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

