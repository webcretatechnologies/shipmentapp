import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

/// First-scan product/label drawer — mirrors the PWA `ws-label-modal`.
/// When a scanned SKU needs its label confirmed, this shows SKU (read-only) +
/// FNSKU / ASIN / EAN (editable), saves via `save-label`, and returns the
/// server response (which carries the refreshed scan_state) so scanning
/// continues. Returns null if cancelled.
Future<Map<String, dynamic>?> showProductLabelDrawer(
  BuildContext context, {
  required String shipmentCode,
  required Map<String, dynamic> product,
  required String barcode,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x800F172A),
    builder: (_) => _ProductLabelDrawer(
      shipmentCode: shipmentCode,
      product: product,
      barcode: barcode,
    ),
  );
}

class _ProductLabelDrawer extends StatefulWidget {
  const _ProductLabelDrawer({
    required this.shipmentCode,
    required this.product,
    required this.barcode,
  });
  final String shipmentCode;
  final Map<String, dynamic> product;
  final String barcode;

  @override
  State<_ProductLabelDrawer> createState() => _ProductLabelDrawerState();
}

class _ProductLabelDrawerState extends State<_ProductLabelDrawer> {
  late final TextEditingController _fnsku;
  late final TextEditingController _asin;
  late final TextEditingController _ean;
  bool _saving = false;
  String? _error;

  String get _sku {
    final p = widget.product;
    final matched = p['matched_marketplace_sku'];
    if (matched is Map && (matched['sku_marketplace'] ?? '').toString().isNotEmpty) {
      return matched['sku_marketplace'].toString();
    }
    return (p['sku'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    _fnsku = TextEditingController(text: (widget.product['fnsku'] ?? '').toString());
    _asin = TextEditingController(text: (widget.product['asin'] ?? '').toString());
    _ean = TextEditingController(text: (widget.product['ean'] ?? '').toString());
  }

  @override
  void dispose() {
    _fnsku.dispose();
    _asin.dispose();
    _ean.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      final api = context.read<ApiClient>();
      final res = await api.post(ApiEndpoints.saveLabel, body: {
        'shipment_id': widget.shipmentCode,
        'product_id': widget.product['id'],
        'barcode': widget.barcode,
        'sku': _sku,
        'fnsku': _fnsku.text.trim(),
        'asin': _asin.text.trim(),
        'ean': _ean.text.trim(),
      });
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      final ok = map['success'] == true || map['status'] == 'success';
      if (!ok) {
        setState(() { _saving = false; _error = (map['message'] ?? 'Could not save label').toString(); });
        return;
      }
      if (mounted) Navigator.of(context).pop(map);
    } catch (e) {
      setState(() { _saving = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = (widget.product['main_image'] ?? '').toString();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confirm product label',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Pwa.text)),
                      SizedBox(height: 2),
                      Text('Verify FNSKU, ASIN, EAN then save to count the scan.',
                          style: TextStyle(fontSize: 12, color: Pwa.muted)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 20, color: Pwa.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Pwa.border),
            const SizedBox(height: 12),
            Row(
              children: [
                if (img.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(img, width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56)),
                    ),
                  ),
                Expanded(child: _readonly('SKU', _sku)),
              ],
            ),
            const SizedBox(height: 12),
            _field('FNSKU', _fnsku),
            const SizedBox(height: 10),
            _field('ASIN', _asin),
            const SizedBox(height: 10),
            _field('EAN', _ean),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: Pwa.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save & continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _readonly(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pwa.muted, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600, color: Pwa.text)),
          ),
        ],
      );

  Widget _field(String label, TextEditingController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pwa.muted, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Pwa.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Pwa.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Pwa.primary)),
            ),
          ),
        ],
      );
}
