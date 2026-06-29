import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';

/// Vendor finance flow for one shipment (spec section 7): submit invoice (PDF) +
/// transport (first vendor), then the last vendor seals the truck → INVOICED.
/// Calls the real supplier mobile endpoints (finance / send-to-finance / seal-truck).
class SupplierFinanceScreen extends StatefulWidget {
  const SupplierFinanceScreen({super.key, required this.shipment});
  final Shipment shipment;

  @override
  State<SupplierFinanceScreen> createState() => _SupplierFinanceScreenState();
}

class _SupplierFinanceScreenState extends State<SupplierFinanceScreen> {
  late ApiClient _api;
  Map<String, dynamic>? _state;
  bool _loading = true;
  bool _busy = false;

  // form fields
  String? _invoicePath;
  final _transporter = TextEditingController();
  final _gst = TextEditingController();
  final _vehicle = TextEditingController();
  final _driver = TextEditingController();
  final _driverNo = TextEditingController();
  final _description = TextEditingController();
  String? _sealPath;
  String? _truckPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    if (_state == null) _load();
  }

  @override
  void dispose() {
    for (final c in [_transporter, _gst, _vehicle, _driver, _driverNo, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get(ApiEndpoints.supplierFinance('${widget.shipment.id}'));
      setState(() => _state = data is Map ? Map<String, dynamic>.from(data) : {});
    } catch (e) {
      _snack('$e', err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickInvoice() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (res != null && res.files.single.path != null) {
      setState(() => _invoicePath = res.files.single.path);
    }
  }

  Future<String?> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    return x?.path;
  }

  Future<void> _submitInvoice() async {
    if (_invoicePath == null) {
      _snack('Pick an invoice file first.', err: true);
      return;
    }
    final transportFilled = _state?['transport_filled'] == true;
    if (!transportFilled &&
        (_transporter.text.isEmpty || _vehicle.text.isEmpty || _driver.text.isEmpty || _driverNo.text.isEmpty)) {
      _snack('Fill all transport details.', err: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.postMultipart(
        ApiEndpoints.supplierSendToFinance('${widget.shipment.id}'),
        fields: {
          'description': _description.text,
          if (!transportFilled) ...{
            'transporter_name': _transporter.text,
            'transporter_gst': _gst.text,
            'vehicle_no': _vehicle.text,
            'driver_name': _driver.text,
            'driver_no': _driverNo.text,
          },
        },
        files: {'invoice_file': _invoicePath!},
      );
      _snack('Invoice submitted.');
      _invoicePath = null;
      await _load();
    } catch (e) {
      _snack('$e', err: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sealTruck() async {
    if (_sealPath == null || _truckPath == null) {
      _snack('Capture both the seal image and truck photo.', err: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.postMultipart(
        ApiEndpoints.supplierSealTruck('${widget.shipment.id}'),
        files: {'seal_image': _sealPath!, 'truck_photo': _truckPath!},
      );
      _snack('Truck sealed — shipment INVOICED.');
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
    final s = _state ?? {};
    final mine = s['my_invoice'];
    final transportFilled = s['transport_filled'] == true;
    final allSubmitted = s['all_submitted'] == true;
    final alreadySealed = s['already_sealed'] == true || s['is_invoiced'] == true;
    final boxDone = s['box_scanning_done'] == true;

    return Scaffold(
      appBar: AppBar(title: Text('Finance · ${widget.shipment.shipmentId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _card(child: Row(
                    children: [
                      Expanded(child: _metric('Invoices in', '${asInt(s['submitted_count'])} / ${asInt(s['assigned_count'])}')),
                      Expanded(child: _metric('Box scanning', boxDone ? 'Done' : 'Pending')),
                    ],
                  )),
                  const SizedBox(height: 14),

                  if (alreadySealed)
                    _banner('Shipment is INVOICED / sealed.', const Color(0xFF1B9C4A))
                  else ...[
                    // ---- Invoice submit ----
                    if (mine != null)
                      _banner('Your invoice has been submitted ✓', const Color(0xFF1B9C4A))
                    else ...[
                      const _Label('Submit your invoice'),
                      if (!boxDone)
                        _banner('Finish box scanning before sending the invoice.', const Color(0xFFE08A00)),
                      _card(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickInvoice,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_invoicePath == null ? 'Pick invoice (PDF/JPG/PNG)' : 'Selected ✓'),
                          ),
                          if (!transportFilled) ...[
                            const SizedBox(height: 12),
                            _field(_transporter, 'Transporter name'),
                            _field(_gst, 'Transporter GST (optional)'),
                            _field(_vehicle, 'Vehicle no'),
                            _field(_driver, 'Driver name'),
                            _field(_driverNo, 'Driver no'),
                          ],
                          _field(_description, 'Description (optional)'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: (_busy || !boxDone) ? null : _submitInvoice,
                            child: _busy ? _spin() : const Text('Send to Finance'),
                          ),
                        ],
                      )),
                    ],

                    const SizedBox(height: 16),
                    // ---- Seal truck (last vendor) ----
                    const _Label('Seal truck (after all invoices in)'),
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!allSubmitted)
                          _banner('Waiting for all vendors to submit invoices.', const Color(0xFFE08A00)),
                        Row(children: [
                          Expanded(child: OutlinedButton.icon(
                            onPressed: allSubmitted ? () async {
                              final p = await _pickImage();
                              if (p != null) setState(() => _sealPath = p);
                            } : null,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(_sealPath == null ? 'Seal photo' : 'Seal ✓'),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: OutlinedButton.icon(
                            onPressed: allSubmitted ? () async {
                              final p = await _pickImage();
                              if (p != null) setState(() => _truckPath = p);
                            } : null,
                            icon: const Icon(Icons.local_shipping_outlined),
                            label: Text(_truckPath == null ? 'Truck photo' : 'Truck ✓'),
                          )),
                        ]),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: (_busy || !allSubmitted) ? null : _sealTruck,
                          child: _busy ? _spin() : const Text('Seal Truck & Mark Invoiced'),
                        ),
                      ],
                    )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _spin() => const SizedBox(
      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
  Widget _card({required Widget child}) =>
      Card(child: Padding(padding: const EdgeInsets.all(14), child: child));
  Widget _metric(String l, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: const TextStyle(color: Colors.black45, fontSize: 12)),
          Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      );
  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(controller: c, decoration: InputDecoration(labelText: label)),
      );
  Widget _banner(String t, Color c) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
      );
}
