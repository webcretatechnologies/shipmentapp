import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/scan_field.dart';
import 'product_label_drawer.dart';
import 'short_sku_drawer.dart';
import 'shipments_repository.dart';

/// Scan screen built to match the warehouse PWA pixel-for-pixel: the
/// SCANNED / TARGET / BOXES stat cards, a teal sticky scan area with an
/// always-ready scan field (hardware scanner types code + Enter → auto-submit
/// + re-focus), an orange "Request short SKU" action that opens a bottom-sheet
/// drawer, and segmented Scan log / Boxes / Expected panels.
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
  int _tab = 0;
  String _expectedSearch = '';

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
      var res = await _repo.scan(shipmentCode: widget.shipmentCode, barcode: code);

      // First scan of a SKU whose label isn't confirmed yet: the backend returns
      // a `product` + "upload the product label" message. Open the product/label
      // drawer (like the PWA), then continue with its save-label response.
      final msg = (res['message'] ?? '').toString();
      if (res['product'] is Map &&
          RegExp(r'product label|upload the product label', caseSensitive: false).hasMatch(msg)) {
        final saved = await showProductLabelDrawer(
          context,
          shipmentCode: widget.shipmentCode,
          product: Map<String, dynamic>.from(res['product'] as Map),
          barcode: code,
        );
        if (saved == null) {
          _flash('Label not saved — scan cancelled.', ok: false);
          return;
        }
        res = saved; // save-label response carries the refreshed scan_state
      }

      final ok = res['success'] == true || res['status'] == 'success';
      _flash((res['message'] ?? res['status'] ?? (ok ? 'Scanned' : 'Failed')).toString(), ok: ok);
      if (res['scan_state'] is Map) {
        var ns = ScanState.fromJson(Map<String, dynamic>.from(res['scan_state']));
        // keep the Expected list if the scan response didn't include products
        if (ns.products.isEmpty && (_state?.products.isNotEmpty ?? false)) {
          ns = ns.withProducts(_state!.products);
        }
        setState(() => _state = ns);
      } else {
        await _refresh();
      }
    } catch (e) {
      _flash('$e', ok: false);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _flash(String m, {required bool ok}) => setState(() {
        _flashMsg = m;
        _flashOk = ok;
      });

  Future<void> _openShortSku() async {
    final ok = await showShortSkuDrawer(context, widget.shipmentId);
    if (ok == true && mounted) {
      _flash('Short SKU request submitted', ok: true);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: Pwa.bg,
      body: Column(
        children: [
          DarkHeader(
            title: widget.shipmentCode.isEmpty ? 'Scan' : widget.shipmentCode,
            subtitle: s == null
                ? 'Scanning in progress'
                : '${(s.areaCode ?? '').isNotEmpty ? 'Area ${s.areaCode} · ' : ''}${s.status.replaceAll('_', ' ')}',
            onBack: () => Navigator.of(context).maybePop(),
            trailing: DarkIconButton(icon: Icons.refresh, onTap: _refresh),
            child: _scanArea(s),
          ),
          _tabBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _tab,
                    children: [
                      _scanLogTab(s),
                      _boxesTab(s),
                      _expectedTab(s),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Scan area, inside the dark header ──
  Widget _scanArea(ScanState? s) {
    return Column(
      children: [
        StatStrip(items: [
          StatItem('${s?.totalScanned ?? 0}', 'Scanned', const Color(0xFF2BC4D4)),
          StatItem('${s?.totalTarget ?? 0}', 'Target', Colors.white),
          StatItem('${s?.boxesScanned ?? 0}/${s?.boxesTotal ?? 0}', 'Boxes', const Color(0xFF22C55E)),
        ]),
        const SizedBox(height: 12),
        ScanField(onSubmit: _onScan, enabled: !_scanning, dark: true, hint: 'Scan or type barcode + Enter'),
        if (_flashMsg != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _flashOk ? const Color(0xFF14532D) : const Color(0xFF7F1D1D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_flashMsg!,
                style: TextStyle(
                    fontSize: 13,
                    color: _flashOk ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                    fontWeight: FontWeight.w500)),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Pwa.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _openShortSku,
            child: const Text('Request Short SKU',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // ── Underline segmented tabs (Scan Log / Boxes / Expected) ──
  Widget _tabBar() {
    const labels = ['Scan Log', 'Boxes', 'Expected'];
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == i ? Pwa.primary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _tab == i ? Pwa.primary : Pwa.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Scan log tab ──
  Widget _scanLogTab(ScanState? s) {
    final log = s?.scanLog ?? const [];
    if (log.isEmpty) return _empty('No scans yet.');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: log.length,
        itemBuilder: (_, i) => _logCard(log[i]),
      ),
    );
  }

  Widget _logCard(ScanLogEntry e) {
    final inBox = e.boxBarcode != null && e.boxBarcode!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(e.merchantSku,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Pwa.text))),
              _qtyBadge('×${e.qty}'),
            ],
          ),
          const SizedBox(height: 6),
          _idGrid([
            if (e.fnsku != null) ('FNSKU', e.fnsku!),
            if (e.asin != null) ('ASIN', e.asin!),
            if (e.ean != null) ('EAN', e.ean!),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: inBox ? Pwa.primaryLight : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(inBox ? 'In box: ${e.boxBarcode}' : 'Not in a box yet',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: inBox ? Pwa.primaryDark : Pwa.muted)),
          ),
          if (e.userName != null || e.updatedAt != null) ...[
            const SizedBox(height: 6),
            Text([if (e.userName != null) e.userName, if (e.updatedAt != null) e.updatedAt].join(' · '),
                style: const TextStyle(fontSize: 12, color: Pwa.muted)),
          ],
        ],
      ),
    );
  }

  // ── Boxes tab ──
  Widget _boxesTab(ScanState? s) {
    final boxes = s?.boxLog ?? const [];
    if (boxes.isEmpty) return _empty('No boxes packed yet.');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: boxes.length,
        itemBuilder: (_, i) {
          final b = boxes[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: _cardDecoration,
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                title: Row(
                  children: [
                    Expanded(
                        child: Text(b.boxBarcode,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Pwa.text))),
                    _pill(b.rackingLabel == null ? 'Open box' : b.rackingLabel!),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${b.lines.length} SKUs · ${b.qty} units',
                      style: const TextStyle(fontSize: 12.5, color: Pwa.muted)),
                ),
                children: b.lines
                    .map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(l.merchantSku,
                                      style: const TextStyle(fontSize: 13, color: Pwa.text))),
                              _qtyBadge('×${l.qty}'),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Expected tab (with PWA search: SKU / FNSKU / ASIN / EAN) ──
  Widget _expectedTab(ScanState? s) {
    // Only show scannable items. A SKU whose pick list hasn't been released has
    // an effective target of 0 (gated) — like the admin scan flow, don't list it.
    final all = (s?.products ?? const []).where((p) => p.expected > 0).toList();
    if (all.isEmpty) return _empty('No expected items.');

    final q = _expectedSearch.trim().toLowerCase();
    final products = q.isEmpty
        ? all
        : all.where((p) {
            bool has(String? v) => v != null && v.toLowerCase().contains(q);
            return has(p.merchantSku) || has(p.title) || has(p.fnsku) || has(p.asin) || has(p.ean);
          }).toList();
    final complete = products.where((p) => p.complete).length;

    return Column(
      children: [
        // search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _expectedSearch = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search SKU, FNSKU, ASIN…',
              prefixIcon: const Icon(Icons.search, size: 20, color: Pwa.muted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Pwa.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Pwa.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Pwa.primary)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${products.length} expected · $complete complete'.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11.5, color: Pwa.muted, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? _empty('No items match “$_expectedSearch”.')
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: products.length,
                    itemBuilder: (_, i) => _expectedCard(products[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _expectedCard(ScanProduct p) {
    final done = p.complete;
    final ratio = p.expected == 0 ? 0.0 : (p.scanned / p.expected).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: done
          ? BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFF0FDF4)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
              boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 14, offset: Offset(0, 4))],
            )
          : _cardDecoration,
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
                    Text(p.merchantSku,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Pwa.text)),
                    if (p.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(p.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Pwa.muted, height: 1.3)),
                      ),
                    if ((p.area ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('Area ${p.area}',
                            style: const TextStyle(
                                fontSize: 11.5, color: Pwa.primaryDark, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _qtyBadge('${p.scanned}/${p.expected}'),
            ],
          ),
          if ((p.fnsku != null) || (p.ean != null) || (p.asin != null)) ...[
            const SizedBox(height: 8),
            _idGrid([
              if (p.fnsku != null) ('FNSKU', p.fnsku!),
              if (p.asin != null) ('ASIN', p.asin!),
              if (p.ean != null) ('EAN', p.ean!),
            ]),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Pwa.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── shared bits (match PWA) ──
  static final _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Pwa.border),
    boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 14, offset: Offset(0, 4))],
  );

  // .ws-qty pill
  Widget _qtyBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: Pwa.primarySoft, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Pwa.primaryDark)),
      );

  // .ws-pill (box status)
  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: Pwa.primaryLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Pwa.primaryBorder)),
        child: Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pwa.primaryDark)),
      );

  // .ws-id-grid (2-column label/value)
  Widget _idGrid(List<(String, String)> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final lines = <Widget>[];
    for (var i = 0; i < rows.length; i += 2) {
      lines.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _idCell(rows[i])),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < rows.length ? _idCell(rows[i + 1]) : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);
  }

  Widget _idCell((String, String) r) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.$1.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: Pwa.muted, letterSpacing: 0.3)),
          Text(r.$2,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Pwa.text)),
        ],
      );

  Widget _empty(String msg) => ListView(children: [
        const SizedBox(height: 80),
        Center(child: Text(msg, style: const TextStyle(color: Pwa.muted))),
      ]);
}
