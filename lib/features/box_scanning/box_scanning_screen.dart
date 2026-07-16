import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/scan_field.dart';
import '../short_box/short_box_screen.dart';
import '../shipments/shipments_repository.dart';

/// Box Scanning Area (spec section 5): list shipments with boxes ready for
/// loading, open one, scan box barcodes to load. Uses
/// GET box-scanning/shipments, GET shipments/{id}/box-loading-state,
/// POST shipments/{id}/box-scan-for-loading.
class BoxScanningScreen extends StatefulWidget {
  const BoxScanningScreen({super.key, this.embedded = false});

  /// When true, renders without its own Scaffold/AppBar so it can live inside a
  /// tab (the Racking + Box Scanning combined screen).
  final bool embedded;

  @override
  State<BoxScanningScreen> createState() => _BoxScanningScreenState();
}

class _BoxScanningScreenState extends State<BoxScanningScreen> {
  late ShipmentsRepository _repo;
  late Future<List<Shipment>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = ShipmentsRepository(context.read<ApiClient>());
    _future = _repo.boxScanningShipments();
  }

  void _reload() => setState(() => _future = _repo.boxScanningShipments());

  @override
  Widget build(BuildContext context) {
    final body = AsyncView<List<Shipment>>(
        future: _future,
        onRetry: _reload,
        builder: (_, items) {
          if (items.isEmpty) return const Center(child: Text('No shipments ready for box scanning.'));
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BoxLoadingScreen(shipment: items[i]),
                )),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0FAFBF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0FAFBF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].shipmentId,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(items[i].status.replaceAll('_', ' '),
                              style: const TextStyle(color: Pwa.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Pwa.muted),
                  ],
                ),
              ),
            ),
          );
        },
      );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: lightAppBar(context, 'Box Scanning'),
      body: body,
    );
  }
}

class BoxLoadingScreen extends StatefulWidget {
  const BoxLoadingScreen({super.key, required this.shipment});
  final Shipment shipment;

  @override
  State<BoxLoadingScreen> createState() => _BoxLoadingScreenState();
}

class _BoxLoadingScreenState extends State<BoxLoadingScreen> {
  late ApiClient _api;
  Map<String, dynamic>? _state;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    if (_state == null) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get(ApiEndpoints.boxLoadingState('${widget.shipment.id}'));
      setState(() => _state = data is Map ? Map<String, dynamic>.from(data) : {});
    } catch (e) {
      _snack('$e', err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanBox(String code) async {
    try {
      final res = await _api.post(ApiEndpoints.boxScanForLoading('${widget.shipment.id}'),
          body: {'box_barcode': code});
      final ok = res is Map && res['success'] == true;
      _snack(res is Map ? '${res['message'] ?? (ok ? 'Box loaded' : 'Failed')}' : 'Done', err: !ok);
      _refresh();
    } catch (e) {
      _snack('$e', err: true);
    }
  }

  void _snack(String m, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: err ? Colors.red.shade600 : null));
  }

  @override
  Widget build(BuildContext context) {
    final scanned = (_state?['scanned_boxes'] as List?) ?? const [];
    final pending = (_state?['pending_boxes'] as List?) ?? const [];
    return Scaffold(
      appBar: lightAppBar(context, widget.shipment.shipmentId, actions: [
        // Short Box — same option the admin box-scanning (box details) page has.
        TextButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ShortBoxScreen(shipmentId: widget.shipment.id),
            ));
            _refresh();
          },
          icon: const Icon(Icons.unarchive_outlined, color: Colors.white, size: 18),
          label: const Text('Short Box',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ]),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ScanField(hint: 'Scan box barcode to load', onSubmit: _scanBox),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(child: _statCard('Loaded', '${scanned.length}', const Color(0xFF22C55E))),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Pending', '${pending.length}', const Color(0xFFF59E0B))),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (pending.isNotEmpty) const SectionLabel('Pending boxes'),
                        ...pending.map((b) => _boxRow(b, false)),
                        if (scanned.isNotEmpty)
                          const SectionLabel('Loaded boxes',
                              padding: EdgeInsets.fromLTRB(2, 14, 2, 10)),
                        ...scanned.map((b) => _boxRow(b, true)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _boxRow(dynamic b, bool done) {
    final code = b is Map ? '${b['box_barcode'] ?? b['barcode'] ?? b}' : '$b';
    final color = done ? const Color(0xFF22C55E) : const Color(0xFF0FAFBF);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(done ? Icons.check : Icons.hexagon_outlined, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pwa.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Pwa.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
}
