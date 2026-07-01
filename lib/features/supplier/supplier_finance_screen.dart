import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/app_ui.dart';

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
  DateTime? _loadingDate; // dispatch step (after finance)
  TimeOfDay? _loadingTime;

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

  // Raise invoice. The LAST vendor (loading the truck) also attaches the seal
  // image + truck photo here, in the same submission.
  Future<void> _submitInvoice({required bool isLast}) async {
    if (_invoicePath == null) {
      _snack('Pick an invoice file first.', err: true);
      return;
    }
    if (isLast) {
      if (_sealPath == null || _truckPath == null) {
        _snack('Attach the seal image and truck photo (you are the last vendor).', err: true);
        return;
      }
      if (_transporter.text.isEmpty || _vehicle.text.isEmpty || _driverNo.text.isEmpty) {
        _snack('Fill the transport details (transporter, vehicle, driver no).', err: true);
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await _api.postMultipart(
        ApiEndpoints.supplierSendToFinance('${widget.shipment.id}'),
        fields: {
          'description': _description.text,
          if (isLast) ...{
            'transporter_name': _transporter.text,
            'transporter_gst': _gst.text,
            'vehicle_no': _vehicle.text,
            'driver_name': _driver.text,
            'driver_no': _driverNo.text,
          },
        },
        files: {
          'invoice_file': _invoicePath!,
          if (isLast && _sealPath != null) 'seal_image': _sealPath!,
          if (isLast && _truckPath != null) 'truck_photo': _truckPath!,
        },
      );
      _snack('Invoice raised — sent to finance.');
      _invoicePath = null;
      _sealPath = null;
      _truckPath = null;
      await _load();
    } catch (e) {
      _snack('$e', err: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Last vendor fills the REMAINING dispatch details (loading date/time, notes)
  // — ONLY after the finance team generated the invoice + e-way bill. Transport
  // details were already captured with the invoice. Moves shipment to IN TRANSIT.
  Future<void> _submitDispatch() async {
    if (_loadingDate == null || _loadingTime == null) {
      _snack('Pick the loading date and time.', err: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final d = _loadingDate!;
      final t = _loadingTime!;
      await _api.post(ApiEndpoints.supplierDispatch('${widget.shipment.id}'), body: {
        'loading_date': '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        'loading_time': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        'description': _description.text,
      });
      _snack('Dispatch details submitted — shipment IN TRANSIT.');
      await _load();
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
    final allSubmitted = s['all_submitted'] == true;
    final alreadySealed = s['already_sealed'] == true;
    final boxDone = s['box_scanning_done'] == true;
    final financeDone = s['finance_done'] == true;      // finance uploaded invoice + e-way bill
    final dispatchDone = s['dispatch_submitted'] == true;
    // The last vendor is the one submitting when everyone else already has.
    final isLastVendor = mine == null &&
        asInt(s['submitted_count']) >= asInt(s['assigned_count']) - 1 &&
        asInt(s['assigned_count']) > 0;

    return Scaffold(
      appBar: lightAppBar(context, 'Invoice · ${widget.shipment.shipmentId}'),
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

                  // ---- Dispatch details (view) — transport + seal/truck ----
                  _dispatchCard(s),

                  // ---- Raise invoice (last vendor also attaches seal + truck) ----
                  if (mine != null)
                    _banner('Your invoice has been submitted ✓', const Color(0xFF1B9C4A))
                  else ...[
                    const _Label('Raise your invoice'),
                    if (!boxDone)
                      _banner('Finish box scanning before raising the invoice.', const Color(0xFFE08A00)),
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickInvoice,
                          icon: const Icon(Icons.attach_file),
                          label: Text(_invoicePath == null ? 'Pick invoice (PDF/JPG/PNG)' : 'Invoice selected ✓'),
                        ),
                        _field(_description, 'Description (optional)'),
                        if (isLastVendor) ...[
                          const SizedBox(height: 12),
                          _banner('You are the last vendor — attach seal + truck photo and the transport details (no e-way bill).', const Color(0xFF0FAFBF)),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(
                              onPressed: () async { final p = await _pickImage(); if (p != null) setState(() => _sealPath = p); },
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: Text(_sealPath == null ? 'Seal photo' : 'Seal ✓'),
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: OutlinedButton.icon(
                              onPressed: () async { final p = await _pickImage(); if (p != null) setState(() => _truckPath = p); },
                              icon: const Icon(Icons.local_shipping_outlined),
                              label: Text(_truckPath == null ? 'Truck photo' : 'Truck ✓'),
                            )),
                          ]),
                          const SizedBox(height: 8),
                          _field(_transporter, 'Transporter name'),
                          _field(_gst, 'Transporter GST (optional)'),
                          _field(_vehicle, 'Vehicle no'),
                          _field(_driver, 'Driver name (optional)'),
                          _field(_driverNo, 'Driver no'),
                        ],
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: (_busy || !boxDone) ? null : () => _submitInvoice(isLast: isLastVendor),
                          child: _busy ? _spin() : const Text('Raise Invoice'),
                        ),
                      ],
                    )),
                  ],

                  // ---- Dispatch details (last vendor, AFTER finance completes) ----
                  if (allSubmitted && alreadySealed && !dispatchDone) ...[
                    const SizedBox(height: 16),
                    const _Label('Dispatch details'),
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!financeDone)
                          _banner('Waiting for the finance team to generate the invoice & e-way bill.', const Color(0xFFE08A00))
                        else ...[
                          _banner('Finance done. Add the remaining dispatch details.', const Color(0xFF1B9C4A)),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null) setState(() => _loadingDate = d);
                              },
                              icon: const Icon(Icons.event),
                              label: Text(_loadingDate == null
                                  ? 'Loading date'
                                  : '${_loadingDate!.day}/${_loadingDate!.month}/${_loadingDate!.year}'),
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: OutlinedButton.icon(
                              onPressed: () async {
                                final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                if (t != null) setState(() => _loadingTime = t);
                              },
                              icon: const Icon(Icons.schedule),
                              label: Text(_loadingTime == null ? 'Loading time' : _loadingTime!.format(context)),
                            )),
                          ]),
                          _field(_description, 'Notes (optional)'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy ? null : _submitDispatch,
                            child: _busy ? _spin() : const Text('Submit Dispatch (Mark In Transit)'),
                          ),
                        ],
                      ],
                    )),
                  ],
                ],
              ),
            ),
    );
  }

  // Dispatch details card — transport info + seal/truck photos (last vendor).
  Widget _dispatchCard(Map<String, dynamic> s) {
    final d = s['dispatch'] is Map ? Map<String, dynamic>.from(s['dispatch']) : null;
    final sealUrl = (s['seal_image_url'] ?? '').toString();
    final truckUrl = (d?['truck_photo_url'] ?? '').toString();
    final builtyUrl = (d?['builty_url'] ?? '').toString();
    final hasAny = d != null &&
        [d['transporter_name'], d['vehicle_no'], d['driver_name'], d['driver_no'], d['eway_bill_no']]
            .any((v) => (v ?? '').toString().isNotEmpty);
    if (!hasAny && sealUrl.isEmpty && truckUrl.isEmpty) return const SizedBox.shrink();

    Widget row(String l, dynamic v) {
      final val = (v ?? '').toString();
      if (val.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(l, style: const TextStyle(color: Colors.black54, fontSize: 13))),
            Expanded(child: Text(val, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );
    }

    Widget thumb(String label, String url) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url, height: 90, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        height: 90, color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.image_not_supported_outlined, color: Colors.black26))),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Dispatch details'),
          if (d != null) ...[
            row('Transporter', d['transporter_name']),
            row('Transporter GST', d['transporter_gst']),
            row('Vehicle no', d['vehicle_no']),
            row('Driver', d['driver_name']),
            row('Driver no', d['driver_no']),
            row('E-way bill', d['eway_bill_no']),
            row('Invoice no', d['invoice_no']),
            row('Invoice date', d['invoice_date']),
            row('Loading date', d['loading_date']),
          ],
          if (sealUrl.isNotEmpty || truckUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sealUrl.isNotEmpty) thumb('Seal image', sealUrl),
                if (sealUrl.isNotEmpty && truckUrl.isNotEmpty) const SizedBox(width: 10),
                if (truckUrl.isNotEmpty) thumb('Truck photo', truckUrl),
              ],
            ),
          ],
          if (builtyUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Builty/LR attached ✓', style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
          ],
        ],
      )),
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
