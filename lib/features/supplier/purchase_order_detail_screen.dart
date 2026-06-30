import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_config.dart';
import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/pwa_app_bar.dart';

/// Full PO detail (header totals + line items) for the vendor.
/// GET supplier/purchase-orders/{id}, with a button to open the PDF.
class PurchaseOrderDetailScreen extends StatefulWidget {
  const PurchaseOrderDetailScreen({super.key, required this.id, required this.poNumber});

  final String id;
  final String poNumber;


  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  late ApiClient _api;
  late Future<Map<String, dynamic>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final data = await _api.get(ApiEndpoints.supplierPoDetail(widget.id));
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> _openPdf() async {
    final cfg = context.read<AppConfig>();
    final uri = Uri.parse('${cfg.apiBaseUrl}${ApiEndpoints.supplierPoPdf(widget.id)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open PDF.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pwaAppBar(widget.poNumber, subtitle: 'Purchase Order'),
      body: AsyncView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (_, po) {
          final items = (po['items'] as List?) ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('PO Number', '${po['po_number'] ?? ''}'),
                      _row('Shipment', '${po['shipment_code'] ?? '—'}'),
                      _row('Status', '${po['status'] ?? '—'}'),
                      _row('Date', '${po['po_date'] ?? '—'}'),
                      const Divider(height: 20),
                      _row('Total Qty', '${po['total_qty'] ?? 0}'),
                      _row('Sub Total', _money(po['sub_total'])),
                      _row('CGST', _money(po['cgst_total'])),
                      _row('SGST', _money(po['sgst_total'])),
                      _row('Grand Total', _money(po['grand_total']), bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...items.whereType<Map>().map((raw) {
                final it = Map<String, dynamic>.from(raw);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${it['merchant_sku'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        if ((it['title'] ?? '').toString().isNotEmpty)
                          Text('${it['title']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Pwa.muted)),
                        if (it['ean'] != null)
                          Text('EAN: ${it['ean']}', style: const TextStyle(fontSize: 11, color: Pwa.muted)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Qty ${it['quantity'] ?? 0} × ${_money(it['purchase_price'])}',
                                style: const TextStyle(fontSize: 13)),
                            Text(_money(it['amount']),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Download PO PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Pwa.muted)),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: bold ? Pwa.primaryDark : Pwa.text)),
          ],
        ),
      );

  String _money(dynamic v) {
    final n = v is num ? v : num.tryParse('${v ?? 0}') ?? 0;
    return '₹${n.toStringAsFixed(2)}';
  }
}
