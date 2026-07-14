import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/shipment.dart';
import '../../app/flavor.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
import 'shipments_repository.dart';

class ShipmentsListScreen extends StatefulWidget {
  const ShipmentsListScreen({super.key, this.title = 'All Shipments', this.source = ShipmentSource.all});
  final String title;
  final ShipmentSource source;

  @override
  State<ShipmentsListScreen> createState() => _ShipmentsListScreenState();
}

enum ShipmentSource { all, kitting, boxScanning }

class _ShipmentsListScreenState extends State<ShipmentsListScreen> {
  late ShipmentsRepository _repo;
  late Future<List<Shipment>> _future;
  String _search = '';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: lightAppBar(context, widget.title),
      body: Column(
        children: [
          if (widget.source == ShipmentSource.all) ...[
            // "Main Scan" context banner — matches the PWA .ws-context-banner card.
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Pwa.border),
                boxShadow: const [
                  BoxShadow(color: Color(0x0F0F172A), blurRadius: 14, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Main Scan',
                      style: TextStyle(
                          color: Pwa.primaryDark, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  SizedBox(height: 3),
                  Text(
                    'Scan SKUs into boxes, view scan log & expected items. Closed boxes move to Warehouse.',
                    style: TextStyle(color: Pwa.muted, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search shipment ID…',
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _search = v;
                  _reload();
                },
              ),
            ),
          ],
          Expanded(
            child: AsyncView<List<Shipment>>(
              future: _future,
              onRetry: _reload,
              builder: (context, items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No shipments found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ShipmentTile(
                      shipment: items[i],
                      onTap: () => context.push(
                        '/shipments/${items[i].id}/scan?code=${items[i].shipmentId}',
                      ),
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

class _ShipmentTile extends StatelessWidget {
  const _ShipmentTile({required this.shipment, required this.onTap});
  final Shipment shipment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Head: code + FC on the left, status pill on the right.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shipment.shipmentId,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Pwa.primaryDark)),
                    if ((shipment.fcName ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(shipment.fcName!,
                            style: const TextStyle(color: Pwa.muted, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(shipment.status),
            ],
          ),
          const SizedBox(height: 10),
          WsProgressBar(shipment.progress),
          const SizedBox(height: 8),
          // Meta: Scanned X / Y   ·   Boxes N
          DefaultTextStyle(
            style: const TextStyle(color: Pwa.muted, fontSize: 12.5),
            child: Row(
              children: [
                _meta('Scanned ', '${shipment.scannedUnits}', ' / ${shipment.totalUnits}'),
                const SizedBox(width: 16),
                _meta('Boxes ', '${shipment.boxesScanned}', ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value, String suffix) => Text.rich(
        TextSpan(
          text: label,
          children: [
            TextSpan(
                text: value,
                style: const TextStyle(color: Pwa.text, fontWeight: FontWeight.w700)),
            TextSpan(text: suffix),
          ],
        ),
      );
}
