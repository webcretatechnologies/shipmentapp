import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/async_view.dart';

/// Short SKU Request (spec section 3): pick shortage items + reason and submit.
/// GET shipments/{id}/short-sku (form data) · POST shipments/{id}/short-sku.
/// If opened from the dashboard (no shipment), prompts to open via a shipment.
class ShortSkuScreen extends StatefulWidget {
  const ShortSkuScreen({super.key, this.shipmentId});
  final int? shipmentId;

  @override
  State<ShortSkuScreen> createState() => _ShortSkuScreenState();
}

class _ShortSkuScreenState extends State<ShortSkuScreen> {
  late ApiClient _api;
  late Future<Map<String, dynamic>> _future;
  final Map<int, String> _selected = {}; // shipment_data_id -> reason

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    if (widget.shipmentId == null) return {};
    final data = await _api.get(ApiEndpoints.shortSku('${widget.shipmentId}'));
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    try {
      await _api.post(ApiEndpoints.shortSku('${widget.shipmentId}'), body: {
        'items': _selected.entries
            .map((e) => {'shipment_data_id': e.key, 'reason': e.value})
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Short SKU request submitted')));
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade600));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shipmentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Short SKU Requests')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Open a shipment from All Shipments, then tap “Short SKU”.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Short SKU Request')),
      body: AsyncView<Map<String, dynamic>>(
        future: _future,
        builder: (_, data) {
          final items = (data['items'] as List?) ?? const [];
          if (items.isEmpty) return const Center(child: Text('No shortage items.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = Map<String, dynamic>.from(items[i] as Map);
              final id = asInt(m['shipment_data_id'] ?? m['id']);
              final selected = _selected.containsKey(id);
              return Card(
                child: CheckboxListTile(
                  value: selected,
                  title: Text('${m['merchant_sku'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Target ${m['target_qty'] ?? '-'} · Scanned ${m['scanned_qty'] ?? 0} · Short ${m['short_qty'] ?? 0}'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected[id] = 'Short';
                    } else {
                      _selected.remove(id);
                    }
                  }),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _selected.isEmpty ? null : _submit,
            child: Text('Submit (${_selected.length})'),
          ),
        ),
      ),
    );
  }
}
