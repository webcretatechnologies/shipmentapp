import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _hardBundle(e),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Hard Bundle'),
              ),
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
