import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/models/plantex.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/scan_field.dart';
import 'plantex_repository.dart';

/// The Plantex scan/pack flow — SAME rules as the web supplier Plantex panel:
/// accept PO → EAN-scan products into a pending cart → scan a box barcode to
/// pack + seal it → minus to correct → direct short → raise invoice.
class PlantexScanScreen extends StatefulWidget {
  const PlantexScanScreen({super.key, required this.id});
  final int id;

  @override
  State<PlantexScanScreen> createState() => _PlantexScanScreenState();
}

class _PlantexScanScreenState extends State<PlantexScanScreen> {
  late PlantexRepository _repo;
  PlantexDetail? _detail;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// Pending EAN lines not yet packed into a box (ean → qty).
  final Map<String, int> _pending = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = PlantexRepository(context.read<ApiClient>());
    if (_detail == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.detail(widget.id);
      setState(() {
        _detail = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _flash(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Pwa.success : Pwa.danger,
        behavior: SnackBarBehavior.floating,
      ));
  }

  int get _pendingCount => _pending.values.fold(0, (a, b) => a + b);

  PlantexItem? _itemByEan(String ean) {
    for (final i in _detail!.items) {
      if (i.ean == ean) return i;
    }
    return null;
  }

  PlantexBox? _boxByBarcode(String code) {
    for (final b in _detail!.boxes) {
      if (b.boxBarcode == code) return b;
    }
    return null;
  }

  /// One scan field classifies the barcode: item EAN → add to cart; box barcode
  /// → pack the cart into it; otherwise error.
  Future<void> _onScan(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _detail == null || _busy) return;

    final box = _boxByBarcode(code);
    if (box != null) {
      if (box.isClosed) {
        _flash('Box ${box.boxBarcode} is already used (closed).', ok: false);
        return;
      }
      if (_pending.isEmpty) {
        _flash('Scan products first, then scan the box to pack them.', ok: false);
        return;
      }
      await _packInto(box);
      return;
    }

    final item = _itemByEan(code);
    if (item == null) {
      _flash('EAN $code is not on this shipment.', ok: false);
      return;
    }
    final already = item.scannedQty + (_pending[code] ?? 0);
    if (already >= item.qty) {
      _flash('${item.merchantSku} already at its PO qty (${item.qty}).', ok: false);
      return;
    }
    setState(() => _pending[code] = (_pending[code] ?? 0) + 1);
    _flash('+1 ${item.merchantSku}  (${already + 1}/${item.qty})');
  }

  void _minusPending(String ean) {
    final n = _pending[ean] ?? 0;
    if (n <= 1) {
      _pending.remove(ean);
    } else {
      _pending[ean] = n - 1;
    }
    setState(() {});
  }

  Future<void> _packInto(PlantexBox box) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pack box?'),
        content: Text('Pack $_pendingCount unit(s) into ${box.boxBarcode} and seal it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pack & seal')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _repo.packBox(
        id: widget.id,
        boxBarcode: box.boxBarcode,
        lines: _pending.entries.map((e) => (ean: e.key, qty: e.value)).toList(),
      );
      _pending.clear();
      _flash('Packed into ${box.boxBarcode}.');
      await _load();
    } on ApiException catch (e) {
      _flash(e.message, ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFromBox(PlantexBox box, PlantexScan scan) async {
    setState(() => _busy = true);
    try {
      await _repo.removeUnit(id: widget.id, boxBarcode: box.boxBarcode, ean: scan.ean, qty: 1);
      _flash('Removed 1 ${scan.sku} from ${box.boxBarcode}.');
      await _load();
    } on ApiException catch (e) {
      _flash(e.message, ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await _repo.accept(widget.id);
      await _load();
    } on ApiException catch (e) {
      _flash(e.message, ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _short() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Short SKU'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This seals any open boxes and marks the shipment short. No approval needed.'),
            const SizedBox(height: 12),
            TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Reason (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Pwa.warning),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Short SKU'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await _repo.markShort(id: widget.id, reason: reason);
      _flash('Shipment marked short.');
      await _load();
    } on ApiException catch (e) {
      _flash(e.message, ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _raiseInvoice() async {
    final changed = await context.push<bool>('/plantex-shipments/${widget.id}/invoice');
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      backgroundColor: Pwa.bg,
      appBar: lightAppBar(context, d?.shipment.shipmentCode ?? 'Plantex', actions: [
        IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBox(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _body(d!)),
    );
  }

  Widget _body(PlantexDetail d) {
    final s = d.shipment;
    final locked = s.isInvoiced;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // ── Summary ──
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('PO ${s.poNumber ?? '—'}  •  ${s.fcName ?? ''}',
                        style: const TextStyle(color: Pwa.muted, fontSize: 12.5)),
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
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Not accepted yet ──
        if (!s.isAccepted) ...[
          AppCard(
            child: Column(
              children: [
                const Text('Accept this PO to start scanning.', style: TextStyle(color: Pwa.muted)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _accept,
                    icon: const Icon(Icons.check),
                    label: const Text('Accept PO'),
                  ),
                ),
              ],
            ),
          ),
        ]

        // ── Locked (invoiced/closed) ──
        else if (locked) ...[
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Pwa.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.isClosed ? 'This shipment is closed (dispatched).' : 'Invoice raised. Waiting for finance approval.',
                    style: const TextStyle(color: Pwa.text, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _raiseInvoice,
            icon: const Icon(Icons.receipt_long),
            label: const Text('View Invoice'),
          ),
        ]

        // ── Active scanning ──
        else ...[
          // Scan input
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Scan product EAN, then scan a box'),
                const SizedBox(height: 8),
                ScanField(onSubmit: _onScan, enabled: !_busy, hint: 'Scan product EAN or box barcode'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pending cart
          if (_pending.isNotEmpty) ...[
            _PendingCart(
              detail: d,
              pending: _pending,
              onMinus: _minusPending,
            ),
            const SizedBox(height: 14),
          ],

          // Open boxes (to pack into)
          _OpenBoxes(boxes: d.openBoxes),
          const SizedBox(height: 14),

          // Expected items
          _ExpectedItems(items: d.items),
          const SizedBox(height: 14),

          // Closed boxes (scan log + minus)
          _ClosedBoxes(
            detail: d,
            onRemove: _removeFromBox,
          ),
          const SizedBox(height: 18),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _short,
                  style: OutlinedButton.styleFrom(foregroundColor: Pwa.warning, side: const BorderSide(color: Pwa.warning)),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Short SKU'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_busy || s.scannedQty == 0) ? null : _raiseInvoice,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Raise Invoice'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────── sub-widgets ───────────────────────────

class _PendingCart extends StatelessWidget {
  const _PendingCart({required this.detail, required this.pending, required this.onMinus});
  final PlantexDetail detail;
  final Map<String, int> pending;
  final void Function(String ean) onMinus;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 18, color: Pwa.primary),
              const SizedBox(width: 6),
              Text('To pack (${pending.values.fold(0, (a, b) => a + b)})',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Pwa.text)),
              const Spacer(),
              const Text('scan a box to seal', style: TextStyle(color: Pwa.muted, fontSize: 12)),
            ],
          ),
          const Divider(height: 18),
          ...pending.entries.map((e) {
            final item = detail.items.firstWhere((i) => i.ean == e.key,
                orElse: () => PlantexItem(id: 0, merchantSku: e.key, itemName: '', ean: e.key, qty: 0, scannedQty: 0, remaining: 0));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.merchantSku, style: const TextStyle(fontWeight: FontWeight.w700, color: Pwa.text)),
                        Text('EAN ${e.key}', style: const TextStyle(color: Pwa.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Text('×${e.value}', style: const TextStyle(fontWeight: FontWeight.w800, color: Pwa.text)),
                  IconButton(
                    onPressed: () => onMinus(e.key),
                    icon: const Icon(Icons.remove_circle_outline, color: Pwa.danger),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OpenBoxes extends StatelessWidget {
  const _OpenBoxes({required this.boxes});
  final List<PlantexBox> boxes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open Boxes (${boxes.length})', style: const TextStyle(fontWeight: FontWeight.w800, color: Pwa.text)),
          const SizedBox(height: 4),
          const Text('Scan one of these after scanning products, to pack + seal it.',
              style: TextStyle(color: Pwa.muted, fontSize: 12)),
          const Divider(height: 18),
          if (boxes.isEmpty)
            const Text('No open boxes.', style: TextStyle(color: Pwa.muted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: boxes
                  .map((b) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Pwa.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Pwa.primaryBorder),
                        ),
                        child: Text(b.boxBarcode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pwa.primaryDark)),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ExpectedItems extends StatelessWidget {
  const _ExpectedItems({required this.items});
  final List<PlantexItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expected Items (${items.length})', style: const TextStyle(fontWeight: FontWeight.w800, color: Pwa.text)),
          const Divider(height: 18),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(i.complete ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18, color: i.complete ? Pwa.success : Pwa.border),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.merchantSku, style: const TextStyle(fontWeight: FontWeight.w700, color: Pwa.text)),
                          Text('EAN ${i.ean}', style: const TextStyle(color: Pwa.muted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Text('${i.scannedQty}/${i.qty}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: i.complete ? Pwa.success : Pwa.text)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ClosedBoxes extends StatelessWidget {
  const _ClosedBoxes({required this.detail, required this.onRemove});
  final PlantexDetail detail;
  final void Function(PlantexBox box, PlantexScan scan) onRemove;

  @override
  Widget build(BuildContext context) {
    final closed = detail.closedBoxes;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Packed Boxes (${closed.length})', style: const TextStyle(fontWeight: FontWeight.w800, color: Pwa.text)),
          const Divider(height: 18),
          if (closed.isEmpty)
            const Text('No boxes packed yet.', style: TextStyle(color: Pwa.muted))
          else
            ...closed.map((b) {
              final scans = detail.scans.where((sc) => sc.boxId == b.id).toList();
              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  title: Text(b.boxBarcode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Pwa.text)),
                  subtitle: Text('${b.scannedQty} units', style: const TextStyle(color: Pwa.muted, fontSize: 12)),
                  children: scans.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(8), child: Text('No lines.', style: TextStyle(color: Pwa.muted)))]
                      : scans
                          .map((sc) => Row(
                                children: [
                                  Expanded(
                                    child: Text('${sc.sku}  ·  EAN ${sc.ean}',
                                        style: const TextStyle(fontSize: 12.5, color: Pwa.text)),
                                  ),
                                  Text('×${sc.qty}', style: const TextStyle(fontWeight: FontWeight.w700, color: Pwa.text)),
                                  IconButton(
                                    onPressed: () => onRemove(b, sc),
                                    icon: const Icon(Icons.remove_circle_outline, color: Pwa.danger, size: 20),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ))
                          .toList(),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40, color: Pwa.muted),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(message, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
