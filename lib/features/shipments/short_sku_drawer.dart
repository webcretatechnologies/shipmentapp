import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';

/// PWA short-SKU drawer (.ws-drawer): a bottom sheet with a search bar, a
/// scrollable list of shortage SKUs (checkbox + reason select per item) and
/// Cancel / Submit actions — same as the warehouse PWA "Request short SKU".
Future<bool?> showShortSkuDrawer(BuildContext context, int shipmentId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x800F172A), // rgba(15,23,42,.5)
    builder: (_) => _ShortSkuDrawer(shipmentId: shipmentId),
  );
}

const _reasons = ['Short', 'Damaged', 'Not received', 'Wrong item', 'Other'];

class _ShortSkuDrawer extends StatefulWidget {
  const _ShortSkuDrawer({required this.shipmentId});
  final int shipmentId;

  @override
  State<_ShortSkuDrawer> createState() => _ShortSkuDrawerState();
}

class _ShortSkuDrawerState extends State<_ShortSkuDrawer> {
  late ApiClient _api;
  late Future<List<Map<String, dynamic>>> _future;
  final Map<int, String> _selected = {}; // shipment_data_id -> reason
  String _search = '';
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await _api.get(ApiEndpoints.shortSku('${widget.shipmentId}'));
    final items = (data is Map ? (data['items'] as List?) : null) ?? const [];
    return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _api.post(ApiEndpoints.shortSku('${widget.shipmentId}'), body: {
        'items': _selected.entries
            .map((e) => {'shipment_data_id': e.key, 'reason': e.value})
            .toList(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Pwa.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // head
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Short SKU request',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Pwa.text)),
                      SizedBox(height: 2),
                      Text('Select short SKUs and choose a reason for each.',
                          style: TextStyle(fontSize: 12, color: Pwa.muted)),
                    ],
                  ),
                ),
                _CloseBtn(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Pwa.border),
            const SizedBox(height: 10),
            // search
            TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search SKU…',
                prefixIcon: const Icon(Icons.search, size: 20, color: Pwa.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Pwa.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Pwa.border)),
              ),
            ),
            const SizedBox(height: 10),
            // list
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                        padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('${snap.error}', style: const TextStyle(color: Pwa.danger))));
                  }
                  final all = snap.data ?? const [];
                  final items = _search.isEmpty
                      ? all
                      : all.where((m) => '${m['merchant_sku'] ?? ''}'.toLowerCase().contains(_search)).toList();
                  if (items.isEmpty) {
                    return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No shortage items.', style: TextStyle(color: Pwa.muted))));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _itemTile(items[i]),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Pwa.border),
            const SizedBox(height: 12),
            // actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Pwa.muted,
                      side: const BorderSide(color: Pwa.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _selected.isEmpty || _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Pwa.warning,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Submit request${_selected.isEmpty ? '' : ' (${_selected.length})'}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> m) {
    final id = asInt(m['shipment_data_id'] ?? m['id']);
    final checked = _selected.containsKey(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Pwa.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: checked,
                  activeColor: Pwa.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected[id] = 'Short';
                    } else {
                      _selected.remove(id);
                    }
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['merchant_sku'] ?? ''}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Pwa.text)),
                    const SizedBox(height: 3),
                    Text(
                        'Short ${m['short_qty'] ?? 0} · Scanned ${m['scanned_qty'] ?? 0}/${m['target_qty'] ?? '-'}',
                        style: const TextStyle(fontSize: 12, color: Pwa.muted)),
                  ],
                ),
              ),
            ],
          ),
          if (checked) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REASON',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pwa.muted, letterSpacing: 0.4)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selected[id],
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Pwa.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Pwa.border)),
                    ),
                    items: _reasons
                        .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => _selected[id] = v ?? 'Short'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CloseBtn extends StatelessWidget {
  const _CloseBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
        child: const Icon(Icons.close, size: 20, color: Pwa.muted),
      ),
    );
  }
}
