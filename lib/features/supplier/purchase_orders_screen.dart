import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_config.dart';
import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
import 'purchase_order_detail_screen.dart';

/// Purchase Orders (spec section 7): vendor views POs raised for them and opens
/// the PO PDF. Endpoints: GET supplier/purchase-orders, GET …/{id}/pdf.
class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});
  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  late ApiClient _api;
  late Future<List<dynamic>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    final data = await _api.get(ApiEndpoints.supplierPurchaseOrders);
    if (data is Map) return (data['items'] ?? data['data'] ?? []) as List;
    if (data is List) return data;
    return const [];
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openPdf(String id) async {
    // The PDF endpoint is token-protected; open in the device browser/viewer.
    final cfg = context.read<AppConfig>();
    final uri = Uri.parse('${cfg.apiBaseUrl}${ApiEndpoints.supplierPoPdf(id)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open PDF.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: lightAppBar(context, 'Purchase Orders'),
      body: AsyncView<List<dynamic>>(
        future: _future,
        onRetry: _reload,
        builder: (_, items) {
          if (items.isEmpty) {
            return const Center(child: Text('No purchase orders.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final po = Map<String, dynamic>.from(items[i] as Map);
                final id = '${po['id']}';
                final poNumber = '${po['po_number'] ?? 'PO #${po['id'] ?? ''}'}';
                final meta = [
                  if (po['shipment_code'] != null) po['shipment_code'],
                  '${po['items_count'] ?? 0} items',
                  '${po['total_qty'] ?? 0} qty',
                  if (po['po_date'] != null) po['po_date'],
                ].join(' · ');
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(poNumber,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          StatusPill('${po['status'] ?? 'OPEN'}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(meta, style: const TextStyle(color: Pwa.muted, fontSize: 12.5)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.12),
                                foregroundColor: const Color(0xFF7C3AED),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => PurchaseOrderDetailScreen(id: id, poNumber: poNumber),
                              )),
                              child: const Text('View Details'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(72, 52),
                              foregroundColor: Pwa.text,
                              side: const BorderSide(color: Pwa.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _openPdf(id),
                            child: const Text('PDF'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
