import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/models/shipment.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
import 'shipments_repository.dart';

enum ShipmentSource { all, kitting, boxScanning }

/// Shipments list (mockup V1/V3): search + status filter chips + cards showing
/// SKUs / Units / Scanned / Appt with a progress bar and a colored status accent.
class ShipmentsListScreen extends StatefulWidget {
  const ShipmentsListScreen({super.key, this.title = 'FBA Shipments', this.source = ShipmentSource.all});
  final String title;
  final ShipmentSource source;

  @override
  State<ShipmentsListScreen> createState() => _ShipmentsListScreenState();
}

class _ShipmentsListScreenState extends State<ShipmentsListScreen> {
  late ShipmentsRepository _repo;
  late Future<List<Shipment>> _future;
  String _search = '';
  String _filter = 'All'; // All | Scanning | Complete

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = ShipmentsRepository(context.read<ApiClient>());
    _future = _load();
  }

  Future<List<Shipment>> _load() {
    switch (widget.source) {
      case ShipmentSource.kitting:
        return _repo.kittingShipments();
      case ShipmentSource.boxScanning:
        return _repo.boxScanningShipments();
      case ShipmentSource.all:
        return _repo.list(search: _search);
    }
  }

  void _reload() => setState(() => _future = _load());

  bool _matchesFilter(Shipment s) {
    if (_filter == 'All') return true;
    final st = s.status.toUpperCase();
    if (_filter == 'Complete') {
      return st.contains('COMPLETE') || st.contains('CLOSED') || st.contains('LOADED') || st.contains('INVOICED');
    }
    if (_filter == 'Scanning') {
      return st.contains('PROGRESS') || st.contains('SCANNING') || st.contains('RELEASE');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Pwa.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: Text(widget.title, style: const TextStyle(color: Pwa.text, fontSize: 22, fontWeight: FontWeight.w800)),
      ),
      backgroundColor: Pwa.bg,
      body: Column(
        children: [
          if (widget.source == ShipmentSource.all)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Pwa.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Pwa.border)),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _search = v;
                  _reload();
                },
              ),
            ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['All', 'Scanning', 'Complete'].map((f) {
                final on = _filter == f;
                final color = f == 'Scanning'
                    ? const Color(0xFFD97706)
                    : (f == 'Complete' ? const Color(0xFF16A34A) : Pwa.primary);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: on ? color.withOpacity(0.14) : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(f, style: TextStyle(color: on ? color : Pwa.muted, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: AsyncView<List<Shipment>>(
              future: _future,
              onRetry: _reload,
              builder: (context, items) {
                final list = items.where(_matchesFilter).toList();
                if (list.isEmpty) return const Center(child: Text('No shipments found.'));
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ShipmentCard(
                      shipment: list[i],
                      onTap: () => context.push('/shipments/${list[i].id}/scan?code=${list[i].shipmentId}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment, required this.onTap});
  final Shipment shipment;
  final VoidCallback onTap;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _appt() {
    final d = shipment.appointmentDate;
    return d == null ? '—' : '${_months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.pillFg(shipment.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Pwa.border),
            boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(14))),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(shipment.shipmentId, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Pwa.text)),
                                  if ((shipment.fcName ?? '').isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(top: 2), child: Text(shipment.fcName!, style: const TextStyle(color: Pwa.muted, fontSize: 12.5))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.pillBg(shipment.status), borderRadius: BorderRadius.circular(999)),
                              child: Text(shipment.status.replaceAll('_', ' '), style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _stat('${shipment.totalSkus}', 'SKUs', Pwa.text),
                            _stat('${shipment.totalUnits}', 'Units', Pwa.text),
                            _stat(shipment.scannedUnits > 0 ? '${shipment.scannedUnits}' : '—', 'Scanned', const Color(0xFF16A34A)),
                            _stat(_appt(), 'Appt.', Pwa.text),
                          ],
                        ),
                        const SizedBox(height: 12),
                        WsProgressBar(shipment.progress),
                        const SizedBox(height: 6),
                        Text('${shipment.scannedUnits} / ${shipment.totalUnits} units scanned', style: const TextStyle(color: Pwa.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color valueColor) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: valueColor)),
            Text(label, style: const TextStyle(color: Pwa.muted, fontSize: 11.5)),
          ],
        ),
      );
}
