import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/shipment.dart';
import '../../core/theme/app_theme.dart';
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
          if (widget.source == ShipmentSource.all)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search shipment code…',
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _search = v;
                  _reload();
                },
              ),
            ),
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
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final color = AppTheme.statusColor(shipment.status);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(shipment.shipmentId,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              StatusPill(shipment.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('SKUs', '${shipment.totalSkus}'),
              _stat('Units', '${shipment.totalUnits}'),
              _stat('Scanned', '${shipment.scannedUnits}'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: shipment.progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: Colors.black45, fontSize: 12)),
          ],
        ),
      );
}
