import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/dashboard_counts.dart';

/// A card is shown only if the logged-in user has access to that module —
/// mirroring their admin-panel permissions.
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
    } catch (_) {/* counts optional */}
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
    final user = auth.user;
    final caps = user?.capabilities ?? const Capabilities();
    final modules = modulesForRole(role).where((m) => _hasAccess(m, caps, role.isSupplier)).toList();

    return Scaffold(
      backgroundColor: Pwa.bg,
      body: FutureBuilder<DashboardCounts>(
        future: _future,
        builder: (context, snap) {
          final counts = snap.data ?? DashboardCounts();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(user, role, counts),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
                  child: Text('QUICK ACCESS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Pwa.muted.withOpacity(0.9))),
                ),
                if (modules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 40, 24, 24),
                    child: Text(
                      'No modules are assigned to your account.\nAsk an admin to grant access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Pwa.muted),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.98,
                      children: modules
                          .map((m) => _ModuleCard(
                                module: m,
                                count: counts.forModule(m.name),
                                onTap: () => context.push(m.route),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Stylish gradient header with the user's name + Pending/Closed stats ──
  Widget _header(AppUser? user, AppRole role, DashboardCounts counts) {
    final name = (user?.name ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final sub = role.isSupplier
        ? 'Vendor Portal'
        : (user?.areaCode?.isNotEmpty == true ? 'Warehouse · Area ${user!.areaCode}' : 'Plantex Warehouse');

    return Container(
      decoration: const BoxDecoration(
        gradient: Pwa.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // avatar
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: Text(initial,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.toUpperCase(),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 2),
                    Text(name.isEmpty ? 'Dashboard' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _iconBtn(Icons.logout, 'Logout', context.read<AuthController>().logout),
            ],
          ),
          const SizedBox(height: 18),
          // Only Pending + Closed (there is no "Active" status).
          Row(
            children: [
              Expanded(child: _statCard('${counts.pending}', 'Pending', const Color(0xFFFCD34D))),
              const SizedBox(width: 12),
              Expanded(child: _statCard('${counts.complete}', 'Closed', const Color(0xFF6EE7B7))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color accent) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: accent, fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 4),
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6)),
          ],
        ),
      );

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.count, required this.onTap});
  final DashboardModule module;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Pwa.border),
            boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 6))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Pwa.primaryLight, Pwa.primarySoft],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(module.icon, color: Pwa.primaryDark, size: 22),
                  ),
                  // Count only for accessible modules (this card only renders when
                  // the user has access) and only when there's something to show.
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Pwa.primary, borderRadius: BorderRadius.circular(20)),
                      child: Text('$count',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                ],
              ),
              const Spacer(),
              Text(module.label,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Pwa.text)),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text('Open', style: TextStyle(color: Pwa.primaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward, size: 13, color: Pwa.primaryDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
