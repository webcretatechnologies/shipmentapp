import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/scan_field.dart';
import 'shipments_repository.dart';

/// Core scanning screen for one shipment (spec section 3):
/// SKU scanning, box scanning, add-SKU-into-box (all via the single
/// `POST shipments/scan` endpoint — product vs box barcode is detected
/// server-side), plus Short SKU / Short Box shortcuts. No admin actions.
class ShipmentScanScreen extends StatefulWidget {
  const ShipmentScanScreen({super.key, required this.shipmentId, required this.shipmentCode});
  final int shipmentId;
  final String shipmentCode;

  @override
  State<ShipmentScanScreen> createState() => _ShipmentScanScreenState();
}

class _ShipmentScanScreenState extends State<ShipmentScanScreen> {
  late ShipmentsRepository _repo;
  ScanState? _state;
  bool _loading = true;
  bool _scanning = false;
  String? _lastMessage;
  Color _lastColor = Colors.green;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = ShipmentsRepository(context.read<ApiClient>());
    if (_state == null) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final s = await _repo.scanState(widget.shipmentId);
      setState(() => _state = s);
    } catch (e) {
      _flash('$e', ok: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onScan(String code) async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final res = await _repo.scan(shipmentCode: widget.shipmentCode, barcode: code);
      final ok = res['success'] == true;
      final msg = (res['message'] ?? res['status'] ?? (ok ? 'Scanned' : 'Failed')).toString();
      _flash(msg, ok: ok);
      // Prefer the scan_state returned inline; otherwise re-fetch.
      if (res['scan_state'] is Map) {
        setState(() => _state = ScanState.fromJson(Map<String, dynamic>.from(res['scan_state'])));
      } else {
        await _refresh();
      }
    } catch (e) {
      _flash('$e', ok: false);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _flash(String msg, {required bool ok}) {
    setState(() {
      _lastMessage = msg;
      _lastColor = ok ? const Color(0xFF1B9C4A) : const Color(0xFFD64545);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shipmentCode.isEmpty ? 'Scan' : widget.shipmentCode),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // scan input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                ScanField(onSubmit: _onScan, enabled: !_scanning),
                if (_lastMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _lastColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_lastMessage!,
                        style: TextStyle(color: _lastColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          // totals
          if (s != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _Metric(label: 'Qty Scanned', value: '${s.totalScanned} / ${s.totalTarget}'),
                  const SizedBox(width: 12),
                  _Metric(label: 'Boxes', value: '${s.boxesScanned} / ${s.boxesTotal}'),
                ],
              ),
            ),
          // products
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: s?.products.length ?? 0,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ProductTile(p: s!.products[i]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/short-sku?shipment=${widget.shipmentId}'),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Short SKU'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/short-box?shipment=${widget.shipmentId}'),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Short Box'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.black45, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.p});
  final ScanProduct p;
  @override
  Widget build(BuildContext context) {
    final done = p.complete;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? const Color(0xFF1B9C4A) : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.merchantSku, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (p.title.isNotEmpty)
                    Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  if (p.ean != null) Text('EAN: ${p.ean}', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${p.scanned}/${p.expected}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
