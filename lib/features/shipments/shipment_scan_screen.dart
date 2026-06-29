import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/pwa_app_bar.dart';
import '../../core/widgets/scan_field.dart';
import 'shipments_repository.dart';

/// Scan screen modelled on the PWA: SCANNED / TARGET / BOXES counters, an
/// always-ready scan field (works with the handheld's hardware scanner — it
/// types the barcode + Enter, the field auto-submits and re-focuses), a
/// "Request short SKU" action, and Scan log / Boxes / Expected tabs.
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
  String? _flashMsg;
  bool _flashOk = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = ShipmentsRepository(context.read<ApiClient>());
    if (_state == null) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _state = await _repo.scanState(widget.shipmentId);
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
      _flash((res['message'] ?? res['status'] ?? (ok ? 'Scanned' : 'Failed')).toString(), ok: ok);
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

  void _flash(String m, {required bool ok}) =>
      setState(() { _flashMsg = m; _flashOk = ok; });

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: pwaAppBar(
          widget.shipmentCode.isEmpty ? 'Scan' : widget.shipmentCode,
          subtitle: s == null
              ? null
              : '${(s.areaCode ?? '').isNotEmpty ? '${s.areaCode} · ' : ''}${s.status.replaceAll('_', ' ')}',
          actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: Colors.white))],
        ),
        body: Column(
          children: [
            // counters
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      PwaCounter(label: 'Scanned', value: '${s?.totalScanned ?? 0} / ${s?.totalTarget ?? 0}'),
                      const SizedBox(width: 10),
                      PwaCounter(label: 'Target', value: '${s?.totalTarget ?? 0}'),
                      const SizedBox(width: 10),
                      PwaCounter(label: 'Boxes', value: '${s?.boxesScanned ?? 0} / ${s?.boxesTotal ?? 0}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('SCAN PRODUCT OR CLOSE BOX BARCODE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                  ),
                  const SizedBox(height: 6),
                  ScanField(onSubmit: _onScan, enabled: !_scanning),
                  if (_flashMsg != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: (_flashOk ? const Color(0xFF1B9C4A) : const Color(0xFFD64545)).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_flashMsg!,
                          style: TextStyle(
                              color: _flashOk ? const Color(0xFF1B9C4A) : const Color(0xFFD64545),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE08A00)),
                      onPressed: () => context.push('/short-sku?shipment=${widget.shipmentId}'),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Request short SKU'),
                    ),
                  ),
                ],
              ),
            ),
            const Material(
              color: Colors.white,
              child: TabBar(
                labelColor: kBrandAccent,
                indicatorColor: kBrandAccent,
                unselectedLabelColor: Colors.black54,
                tabs: [
                  Tab(text: 'Scan log'),
                  Tab(text: 'Boxes'),
                  Tab(text: 'Expected'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _scanLogTab(s),
                        _boxesTab(s),
                        _expectedTab(s),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Scan log tab ──
  Widget _scanLogTab(ScanState? s) {
    final log = s?.scanLog ?? const [];
    if (log.isEmpty) return _empty('No scans yet.');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: log.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e = log[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.merchantSku, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: kBrandAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text('×${e.qty}',
                            style: const TextStyle(color: kBrandAccent, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (e.fnsku != null) Text('FNSKU: ${e.fnsku}', style: _meta),
                  if (e.ean != null) Text('EAN: ${e.ean}', style: _meta),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e.boxBarcode == null || e.boxBarcode!.isEmpty
                        ? 'Not in a box yet'
                        : 'Box: ${e.boxBarcode}', style: _meta),
                  ),
                  const SizedBox(height: 4),
                  Text([if (e.userName != null) e.userName, if (e.updatedAt != null) e.updatedAt].join(' · '),
                      style: const TextStyle(fontSize: 11, color: Colors.black38)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Boxes tab ──
  Widget _boxesTab(ScanState? s) {
    final boxes = s?.boxLog ?? const [];
    if (boxes.isEmpty) return _empty('No boxes packed yet.');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: boxes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final b = boxes[i];
          return Card(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              title: Text(b.boxBarcode, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${b.qty} units${b.rackingLabel != null ? ' · ${b.rackingLabel}' : ''}', style: _meta),
              children: b.lines
                  .map((l) => ListTile(
                        dense: true,
                        title: Text(l.merchantSku, style: const TextStyle(fontSize: 13)),
                        trailing: Text('×${l.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  // ── Expected tab ──
  Widget _expectedTab(ScanState? s) {
    final products = s?.products ?? const [];
    if (products.isEmpty) return _empty('No expected items.');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = products[i];
          final done = p.complete;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                          Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _meta),
                        if (p.ean != null) Text('EAN: ${p.ean}', style: _meta),
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
        },
      ),
    );
  }

  Widget _empty(String msg) => ListView(children: [
        const SizedBox(height: 80),
        Center(child: Text(msg, style: const TextStyle(color: Colors.black54))),
      ]);

  static const _meta = TextStyle(fontSize: 12, color: Colors.black54);
}
