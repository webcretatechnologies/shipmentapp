import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
import '../shipments/shipments_repository.dart';
import 'supplier_finance_screen.dart';

/// Supplier invoice flow (spec section 7): after the vendor's box scanning is
/// complete, submit the invoice (and the last vendor seals the truck).
///
/// Mirrors the web SupplierShipmentController (sendToFinance / sealTruck).
/// Needs the supplier mobile endpoints added to api.php:
///   GET  supplier/shipments/{id}/finance
///   POST supplier/shipments/{id}/send-to-finance   (multipart: invoice PDF + transport)
///   POST supplier/shipments/{id}/seal-truck        (multipart: seal + truck photo)
class SupplierInvoiceScreen extends StatefulWidget {
  const SupplierInvoiceScreen({super.key});
  @override
  State<SupplierInvoiceScreen> createState() => _SupplierInvoiceScreenState();
}

class _SupplierInvoiceScreenState extends State<SupplierInvoiceScreen> {
  late ShipmentsRepository _repo;
  late Future<List<Shipment>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = ShipmentsRepository(context.read<ApiClient>());
    // Vendor's shipments are auto-scoped by the backend's vendorAssigned global
    // scope, so the same /shipments endpoint returns only this vendor's data.
    _future = _repo.list();
  }

  void _reload() => setState(() => _future = _repo.list());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: lightAppBar(context, 'Invoices'),
      body: AsyncView<List<Shipment>>(
        future: _future,
        onRetry: _reload,
        builder: (_, items) {
          // Vendor flow: box-scanning done → ready for invoice.
          final ready = items.where((s) =>
              s.status.toUpperCase().contains('SCAN') ||
              s.status.toUpperCase().contains('BOX') ||
              s.status.toUpperCase().contains('INVOICE')).toList();
          final list = ready.isEmpty ? items : ready;
          if (list.isEmpty) return const Center(child: Text('No shipments to invoice.'));
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final s = list[i];
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(s.shipmentId,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          StatusPill(s.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${s.totalUnits} units · ${s.totalSkus} SKUs',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SupplierFinanceScreen(shipment: s),
                          )),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Upload Invoice'),
                        ),
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
