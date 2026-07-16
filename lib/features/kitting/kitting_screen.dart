import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/scan_field.dart';
import '../shipments/shipments_repository.dart';

/// Kitting Process (spec section 6): list shipments with combo SKUs and their
/// kitting status. Uses GET kitting/shipments.
///
/// NOTE: the per-entry kitting ACTIONS (hard-bundle, merge, child-SKU scan) are
/// driven by the combo-workflow endpoints. Add the mobile routes for them
/// (see api.php "kitting actions") and wire `KittingDetailScreen` to call them.
class KittingScreen extends StatefulWidget {
  const KittingScreen({super.key});
  @override
  State<KittingScreen> createState() => _KittingScreenState();
}

class _KittingScreenState extends State<KittingScreen> {
  late ShipmentsRepository _repo;
  late ApiClient _api;
  late Future<List<Shipment>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _repo = ShipmentsRepository(_api);
    _future = _repo.kittingShipments();
  }

  void _reload() => setState(() => _future = _repo.kittingShipments());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: lightAppBar(context, 'Kitting Process'),
      bottomNavigationBar: const AppBottomNav(current: 3),
      body: AsyncView<List<Shipment>>(
        future: _future,
        onRetry: _reload,
        builder: (_, items) {
          if (items.isEmpty) return const Center(child: Text('No kitting shipments.'));
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => KittingDetailScreen(shipment: items[i]),
                )),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0FAFBF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.dashboard_customize_outlined, color: Color(0xFF0FAFBF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(items[i].shipmentId,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    StatusPill(items[i].status),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: Pwa.muted),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class KittingDetailScreen extends StatefulWidget {
  const KittingDetailScreen({super.key, required this.shipment});
  final Shipment shipment;

  @override
  State<KittingDetailScreen> createState() => _KittingDetailScreenState();
}

class _KittingDetailScreenState extends State<KittingDetailScreen> {
  late ApiClient _api;
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final data = await _api.get(ApiEndpoints.kittingDetail('${widget.shipment.id}'));
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _hardBundle(Map<String, dynamic> e) async {
    final ordered = asInt(e['qty_ordered']);
    final hb = asInt(e['hard_bundle_qty']);
    final kitted = asInt(e['kitted_qty']);
    final max = ordered - hb - kitted;
    if (max < 1) {
      _snack('Nothing left to hard bundle.', err: true);
      return;
    }
    final ctrl = TextEditingController(text: '1');
    final qty = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hard bundle — ${e['merchant_sku'] ?? ''}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Qty (max $max)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (qty == null || qty < 1) return;
    setState(() => _busy = true);
    try {
      final res = await _api.post(ApiEndpoints.kittingHardBundle('${e['entry_id']}'), body: {'qty': qty});
      _snack(res is Map ? '${res['message'] ?? 'Hard bundled'}' : 'Hard bundled');
      _reload();
    } catch (err) {
      _snack('$err', err: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanToKit(Map<String, dynamic> e) async {
    final ordered = asInt(e['qty_ordered']);
    final hb = asInt(e['hard_bundle_qty']);
    final kitted = asInt(e['kitted_qty']);
    if (ordered - hb - kitted < 1) {
      _snack('Nothing left to kit for this combo.', err: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KitScanSheet(
        api: _api,
        shipmentId: widget.shipment.id,
        entry: e,
      ),
    );
    // Refresh the entry breakdown after kitting (counts may have changed).
    _reload();
  }

  Future<void> _mergeAll() async {
    setState(() => _busy = true);
    try {
      final res = await _api.post(ApiEndpoints.kittingMerge('${widget.shipment.id}'));
      _snack(res is Map ? '${res['message'] ?? 'Merged'}' : 'Merged');
      _reload();
    } catch (err) {
      _snack('$err', err: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: err ? Colors.red.shade600 : null));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: lightAppBar(context, 'Kitting · ${widget.shipment.shipmentId}'),
      body: AsyncView<Map<String, dynamic>>(
        future: _future,
        onRetry: _reload,
        builder: (_, data) {
          final entries = (data['entries'] as List?) ?? const [];
          if (entries.isEmpty) {
            return const Center(child: Text('No combo entries for this shipment.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(widget.shipment.shipmentId,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          StatusPill(widget.shipment.status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (final raw in entries) _entryCard(Map<String, dynamic>.from(raw as Map)),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _mergeAll,
                        icon: const Icon(Icons.merge_type, size: 18),
                        label: const Text('Merge All'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: Pwa.text,
                          side: const BorderSide(color: Pwa.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> e) {
    final toKit = asInt(e['to_kit']);
    final merged = e['merged'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Pwa.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pwa.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${e['merchant_sku'] ?? e['combo_sku_code'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Ordered', '${asInt(e['qty_ordered'])}', Pwa.muted),
            _chip('Kitted', '${asInt(e['kitted_qty'])}', const Color(0xFF16A34A)),
            _chip('To Kit', '$toKit', toKit > 0 ? const Color(0xFF0C8E9C) : Pwa.muted),
          ]),
          if (!merged && toKit > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _scanToKit(e),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan to Kit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _hardBundle(e),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Hard Bundle'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: Pwa.text,
                      side: const BorderSide(color: Pwa.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String l, String v, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Pwa.border),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$l: ', style: const TextStyle(fontSize: 12, color: Pwa.muted)),
          TextSpan(
              text: v,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ])),
      );
}

/// Scan-to-kit bottom sheet. Scan the combo's child SKUs in order, then the
/// parent SKU, exactly like the admin panel — the server drives the sequence
/// (POST /shipments/{id}/kitting/scan). Each result is appended to a live log.
class _KitScanSheet extends StatefulWidget {
  const _KitScanSheet({
    required this.api,
    required this.shipmentId,
    required this.entry,
  });

  final ApiClient api;
  final int shipmentId;
  final Map<String, dynamic> entry;

  @override
  State<_KitScanSheet> createState() => _KitScanSheetState();
}

class _KitScanSheetState extends State<_KitScanSheet> {
  final List<_ScanLine> _log = [];
  bool _busy = false;
  int _kitted = 0;
  int _target = 0;

  @override
  void initState() {
    super.initState();
    _kitted = asInt(widget.entry['kitted_qty']);
    _target = asInt(widget.entry['qty_ordered']) - asInt(widget.entry['hard_bundle_qty']);
  }

  Future<void> _onScan(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await widget.api.post(
        ApiEndpoints.kittingScan('${widget.shipmentId}'),
        body: {'barcode': code, 'combo_entry_id': widget.entry['entry_id']},
      );
      final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      final ok = m['success'] == true;
      if (m.containsKey('main_sku_scan_count')) _kitted = asInt(m['main_sku_scan_count']);
      if (m.containsKey('kitting_target')) _target = asInt(m['kitting_target']);
      _push(m['message']?.toString() ?? (ok ? 'Scanned' : 'Not matched'), ok);
    } on ApiException catch (e) {
      final data = e.data;
      final msg = data is Map && data['message'] != null ? '${data['message']}' : e.message;
      _push(msg, false);
    } catch (err) {
      _push('$err', false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _push(String msg, bool ok) {
    setState(() => _log.insert(0, _ScanLine(msg, ok)));
  }

  @override
  Widget build(BuildContext context) {
    final sku = widget.entry['merchant_sku'] ?? widget.entry['combo_sku_code'] ?? '';
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final done = _target > 0 && _kitted >= _target;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Pwa.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Scan to Kit · $sku',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: done ? const Color(0xFF16A34A).withOpacity(0.10) : Pwa.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(done ? Icons.check_circle : Icons.info_outline,
                      size: 18, color: done ? const Color(0xFF16A34A) : Pwa.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      done
                          ? 'All sets kitted ($_kitted/$_target). Close and Merge.'
                          : 'Kitted $_kitted / $_target — scan child SKUs in order, then the parent SKU.',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ScanField(
              onSubmit: _onScan,
              enabled: !_busy && !done,
              hint: 'Scan child / parent SKU',
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            SizedBox(
              height: 200,
              child: _log.isEmpty
                  ? const Center(
                      child: Text('Scan a barcode to begin.',
                          style: TextStyle(color: Pwa.muted)))
                  : ListView.separated(
                      itemCount: _log.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final line = _log[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(line.ok ? Icons.check_circle : Icons.error_outline,
                                size: 16,
                                color: line.ok ? const Color(0xFF16A34A) : Pwa.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(line.msg,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: line.ok ? Pwa.text : Pwa.danger)),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanLine {
  _ScanLine(this.msg, this.ok);
  final String msg;
  final bool ok;
}
