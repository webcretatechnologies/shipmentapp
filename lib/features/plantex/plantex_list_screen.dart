import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/models/plantex.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
import 'plantex_repository.dart';

/// Plantex (PO-based) vendor shipments — the vendor accepts a PO, EAN-scans into
/// boxes, and raises an invoice. Mirrors the web supplier "Plantex Shipment" tab.
class PlantexListScreen extends StatefulWidget {
  const PlantexListScreen({super.key});

  @override
  State<PlantexListScreen> createState() => _PlantexListScreenState();
}

class _PlantexListScreenState extends State<PlantexListScreen> {
  late PlantexRepository _repo;
  late Future<List<PlantexShipment>> _future;
  String _search = '';
  String _filter = 'All'; // All | To Scan | Invoiced

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = PlantexRepository(context.read<ApiClient>());
    _future = _repo.list(search: _search);
  }

  void _reload() => setState(() => _future = _repo.list(search: _search));

  bool _matches(PlantexShipment s) {
    if (_filter == 'All') return true;
    if (_filter == 'Invoiced') return s.isInvoiced;
    if (_filter == 'To Scan') return !s.isInvoiced;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pwa.bg,
      appBar: lightAppBar(context, 'Plantex Shipments'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search PO / shipment…',
                prefixIcon: Icon(Icons.search),
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
              children: ['All', 'To Scan', 'Invoiced'].map((f) {
                final on = _filter == f;
                final color = f == 'Invoiced' ? Pwa.primary : (f == 'To Scan' ? Pwa.warning : Pwa.text);
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
            child: AsyncView<List<PlantexShipment>>(
              future: _future,
              onRetry: _reload,
              builder: (context, items) {
                final list = items.where(_matches).toList();
                if (list.isEmpty) return const Center(child: Text('No Plantex shipments.'));
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _PlantexCard(
                      s: list[i],
                      onTap: () async {
                        await context.push('/plantex-shipments/${list[i].id}');
                        _reload();
                      },
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

class _PlantexCard extends StatelessWidget {
  const _PlantexCard({required this.s, required this.onTap});
  final PlantexShipment s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.pillFg(s.status);
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
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
                              Text(s.shipmentCode, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Pwa.text)),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('PO ${s.poNumber ?? '—'}  •  ${s.fcName ?? ''}',
                                    style: const TextStyle(color: Pwa.muted, fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(s.statusLabel),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StatStrip(items: [
                      StatItem('${s.totalItems}', 'SKUs', Pwa.text),
                      StatItem('${s.totalQty}', 'Qty', Pwa.text),
                      StatItem('${s.scannedQty}', 'Scanned', Pwa.success),
                      StatItem('${s.closedBoxes}/${s.totalBoxes}', 'Boxes', Pwa.text),
                    ]),
                    const SizedBox(height: 12),
                    WsProgressBar(s.progress),
                    const SizedBox(height: 6),
                    Text('${s.scannedQty} / ${s.totalQty} units scanned', style: const TextStyle(color: Pwa.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
