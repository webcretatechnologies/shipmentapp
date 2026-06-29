import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
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
      appBar: AppBar(title: const Text('Kitting Process')),
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
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => Card(
                child: ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: Text(items[i].shipmentId, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(items[i].status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => KittingDetailScreen(shipment: items[i]),
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
      appBar: AppBar(
        title: Text('Kitting · ${widget.shipment.shipmentId}'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _mergeAll,
            child: const Text('Merge all', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = Map<String, dynamic>.from(entries[i] as Map);
                final toKit = asInt(e['to_kit']);
                final merged = e['merged'] == true;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e['merchant_sku'] ?? e['combo_sku_code'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 12, runSpacing: 4, children: [
                          _chip('Ordered', '${asInt(e['qty_ordered'])}'),
                          _chip('Hard bundled', '${asInt(e['hard_bundle_qty'])}'),
                          _chip('Kitted', '${asInt(e['kitted_qty'])}'),
                          _chip('To kit', '$toKit'),
                          _chip('Status', '${e['status'] ?? ''}'),
                        ]),
                        if (!merged && toKit > 0) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : () => _hardBundle(e),
                              icon: const Icon(Icons.inventory_2_outlined, size: 18),
                              label: const Text('Hard bundle'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String l, String v) => Chip(
        label: Text('$l: $v', style: const TextStyle(fontSize: 12)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
