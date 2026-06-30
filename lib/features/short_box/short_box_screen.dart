import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';

/// Short Box Request (spec section 3). The backend takes a shipment-level
/// `warehouse_reason` (+ optional note), not a box selection.
/// GET shipments/{id}/short-box · POST shipments/{id}/short-box.
class ShortBoxScreen extends StatefulWidget {
  const ShortBoxScreen({super.key, this.shipmentId});
  final int? shipmentId;

  @override
  State<ShortBoxScreen> createState() => _ShortBoxScreenState();
}

class _ShortBoxScreenState extends State<ShortBoxScreen> {
  late ApiClient _api;
  late Future<Map<String, dynamic>> _future;
  String? _reasonKey;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _future = _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    if (widget.shipmentId == null) return {};
    final data = await _api.get(ApiEndpoints.shortBox('${widget.shipmentId}'));
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> _submit() async {
    if (_reasonKey == null) {
      _snack('Select a reason.', err: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.post(ApiEndpoints.shortBox('${widget.shipmentId}'), body: {
        'warehouse_reason': _reasonKey,
        'warehouse_reason_note': _note.text,
      });
      _snack('Short box request submitted');
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      _snack('$e', err: true);
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
    if (widget.shipmentId == null) {
      return Scaffold(
        appBar: lightAppBar(context, 'Short Box Requests'),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Open a shipment from All Shipments, then tap “Short Box”.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: lightAppBar(context, 'Short Box Request'),
      body: AsyncView<Map<String, dynamic>>(
        future: _future,
        builder: (_, data) {
          final reasons = (data['reasons'] is Map)
              ? Map<String, dynamic>.from(data['reasons'])
              : <String, dynamic>{};
          final pending = (data['pending_boxes_list'] as List?) ?? const [];
          final totals = data['totals'] is Map ? Map<String, dynamic>.from(data['totals']) : {};
          final existing = data['existing_request'];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (existing != null)
                Card(
                  color: const Color(0xFFFFF6E5),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Color(0xFFE08A00)),
                    title: Text('Existing request: ${existing['status'] ?? ''}'),
                    subtitle: Text('${existing['warehouse_reason_label'] ?? ''}'),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _t('Total', '${totals['total_boxes'] ?? 0}'),
                      _t('Scanned', '${totals['scanned_boxes'] ?? 0}'),
                      _t('Pending', '${totals['pending_boxes'] ?? pending.length}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Reason', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...reasons.entries.map((e) => RadioListTile<String>(
                    value: e.key,
                    groupValue: _reasonKey,
                    title: Text('${e.value}'),
                    onChanged: (v) => setState(() => _reasonKey = v),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Pending boxes', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...pending.map((b) {
                  final m = Map<String, dynamic>.from(b as Map);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${m['box_barcode'] ?? ''}'),
                      subtitle: Text('${m['sku_count'] ?? 0} SKUs · ${m['total_qty'] ?? 0} units'),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: (_busy || _reasonKey == null) ? null : _submit,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Request'),
          ),
        ),
      ),
    );
  }

  Widget _t(String l, String v) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(l, style: const TextStyle(color: Colors.black45, fontSize: 12)),
          ],
        ),
      );
}
