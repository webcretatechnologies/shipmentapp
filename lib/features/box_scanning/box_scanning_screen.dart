import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/scan_field.dart';
import '../shipments/shipments_repository.dart';

/// Box Scanning Area (spec section 5): list shipments with boxes ready for
/// loading, open one, scan box barcodes to load. Uses
/// GET box-scanning/shipments, GET shipments/{id}/box-loading-state,
/// POST shipments/{id}/box-scan-for-loading.
class BoxScanningScreen extends StatefulWidget {
  const BoxScanningScreen({super.key});
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
    return Scaffold(
      appBar: AppBar(title: const Text('Box Scanning')),
      body: AsyncView<List<Shipment>>(
        future: _future,
        onRetry: _reload,
        builder: (_, items) {
          if (items.isEmpty) return const Center(child: Text('No shipments ready for box scanning.'));
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => Card(
                child: ListTile(
                  title: Text(items[i].shipmentId, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(items[i].status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BoxLoadingScreen(shipment: items[i]),
                  )),
                ),
              ),
            ),
          );
        },
      ),
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
      appBar: AppBar(title: Text(widget.shipment.shipmentId)),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: ScanField(hint: 'Scan box barcode to load', onSubmit: _scanBox),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _pill('Loaded', '${scanned.length}', const Color(0xFF1B9C4A))),
                const SizedBox(width: 10),
                Expanded(child: _pill('Pending', '${pending.length}', const Color(0xFFE08A00))),
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
                        if (pending.isNotEmpty) const _SectionLabel('Pending boxes'),
                        ...pending.map((b) => _boxRow(b, false)),
                        if (scanned.isNotEmpty) const _SectionLabel('Loaded boxes'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(done ? Icons.check_circle : Icons.inventory_2_outlined,
            color: done ? const Color(0xFF1B9C4A) : Colors.grey),
        title: Text(code),
      ),
    );
  }

  Widget _pill(String label, String value, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.black45, fontSize: 12)),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
      );
}
