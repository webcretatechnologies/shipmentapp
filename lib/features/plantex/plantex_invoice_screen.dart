import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/models/plantex.dart';
import '../../core/widgets/app_ui.dart';
import 'plantex_repository.dart';

/// Raise (or view) the vendor invoice for a Plantex shipment — dispatch details
/// + invoice file. Mirrors MobilePlantexController::raiseInvoice (multipart).
class PlantexInvoiceScreen extends StatefulWidget {
  const PlantexInvoiceScreen({super.key, required this.id});
  final int id;

  @override
  State<PlantexInvoiceScreen> createState() => _PlantexInvoiceScreenState();
}

class _PlantexInvoiceScreenState extends State<PlantexInvoiceScreen> {
  late PlantexRepository _repo;
  PlantexShipment? _s;
  bool _loading = true;
  bool _busy = false;

  final _transporter = TextEditingController();
  final _gst = TextEditingController();
  final _vehicle = TextEditingController();
  final _driver = TextEditingController();
  final _driverNo = TextEditingController();
  final _notes = TextEditingController();
  String? _invoicePath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = PlantexRepository(context.read<ApiClient>());
    if (_s == null) _load();
  }

  @override
  void dispose() {
    for (final c in [_transporter, _gst, _vehicle, _driver, _driverNo, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _repo.detail(widget.id);
      setState(() {
        _s = d.shipment;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      _flash(e.message, ok: false);
    }
  }

  void _flash(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Pwa.success : Pwa.danger,
        behavior: SnackBarBehavior.floating,
      ));
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

  Future<void> _submit() async {
    if (_transporter.text.trim().isEmpty ||
        _vehicle.text.trim().isEmpty ||
        _driver.text.trim().isEmpty ||
        _driverNo.text.trim().isEmpty) {
      _flash('Transporter, vehicle, driver name and driver number are required.', ok: false);
      return;
    }
    if (_invoicePath == null) {
      _flash('Please attach the invoice file.', ok: false);
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.raiseInvoice(
        id: widget.id,
        dispatch: {
          'transporter_name': _transporter.text.trim(),
          'transporter_gst': _gst.text.trim(),
          'vehicle_no': _vehicle.text.trim(),
          'driver_name': _driver.text.trim(),
          'driver_no': _driverNo.text.trim(),
          'dispatch_notes': _notes.text.trim(),
        },
        invoiceFilePath: _invoicePath,
      );
      _flash('Invoice raised.');
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      _flash(e.message, ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: Pwa.bg,
      appBar: lightAppBar(context, 'Raise Invoice'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? const Center(child: Text('Not found.'))
              : (s.isInvoiced ? _readOnly(s) : _form(s)),
    );
  }

  // Already invoiced → show status (summary API has no dispatch detail fields).
  Widget _readOnly(PlantexShipment s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.receipt_long, color: Pwa.primary),
                const SizedBox(width: 10),
                Text(s.shipmentCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Pwa.text)),
                const Spacer(),
                StatusPill(s.statusLabel),
              ]),
              const Divider(height: 22),
              _kv('PO Number', s.poNumber ?? '—'),
              _kv('Total Qty', '${s.totalQty}'),
              _kv('Scanned', '${s.scannedQty}'),
              _kv('Boxes', '${s.closedBoxes}/${s.totalBoxes}'),
              _kv('Invoice', s.invoiceApproved ? 'Approved by finance' : 'Awaiting finance approval'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          s.invoiceApproved
              ? 'Finance has approved this invoice. The shipment will be closed on dispatch.'
              : 'Your invoice has been submitted. Finance will review the packed boxes vs the PO and approve it.',
          style: const TextStyle(color: Pwa.muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _form(PlantexShipment s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dispatch details — ${s.shipmentCode}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Pwa.text)),
              const SizedBox(height: 4),
              Text('${s.closedBoxes} box(es) · ${s.scannedQty} units packed',
                  style: const TextStyle(color: Pwa.muted, fontSize: 12.5)),
              const Divider(height: 22),
              _field(_transporter, 'Transporter name *'),
              _field(_gst, 'Transporter GST'),
              _field(_vehicle, 'Vehicle number *'),
              _field(_driver, 'Driver name *'),
              _field(_driverNo, 'Driver number *', keyboard: TextInputType.phone),
              _field(_notes, 'Dispatch notes', maxLines: 2),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Invoice file (PDF / image) *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _invoicePath == null ? 'No file chosen' : _invoicePath!.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _invoicePath == null ? Pwa.muted : Pwa.text, fontSize: 13),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickInvoice,
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Choose'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
          label: Text(_busy ? 'Submitting…' : 'Raise Invoice'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1, TextInputType? keyboard}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Pwa.muted, fontSize: 13))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, color: Pwa.text, fontSize: 13.5))),
          ],
        ),
      );
}
