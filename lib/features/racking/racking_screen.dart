import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/scan_field.dart';

/// Racking Area (spec section 4) — mirrors the warehouse PWA:
/// 1. Receive a pending box into a rack/bin (rack & bin are optional) via a
///    bottom-sheet drawer.
/// 2. Send a received box to Box Scanning. A dock number is asked the first
///    time a shipment is sent (required); subsequent boxes just confirm.
/// Uses GET racking, POST racking/{id}/receive|send, GET racking/lookup.
class RackingScreen extends StatefulWidget {
  const RackingScreen({super.key});
  @override
  State<RackingScreen> createState() => _RackingScreenState();
}

class _RackingScreenState extends State<RackingScreen> {
  late ApiClient _api;
  late Future<List<RackingBox>> _future;
  String _status = 'pending';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
    _future = _load();
  }

  Future<List<RackingBox>> _load() async {
    // unwrapped payload = {items:[...], counts:{pending,received}}
    final data = await _api.get(ApiEndpoints.racking, query: {'status': _status});
    final list = data is Map ? (data['items'] ?? data['boxes'] ?? data['racking'] ?? []) : data;
    return (list as List? ?? [])
        .whereType<Map>()
        .map((e) => RackingBox.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  void _reload() => setState(() => _future = _load());

  void _setStatus(String s) {
    if (_status == s) return;
    _status = s;
    _reload();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade600 : null),
    );
  }

  // ── Receive: drawer with Rack No. (optional) + Bin No. (optional) ──
  Future<void> _receiveBox(RackingBox box) async {
    final rackC = TextEditingController(text: box.rackNo ?? '');
    final binC = TextEditingController(text: box.binNo ?? '');
    final ok = await _sheet<bool>(
      title: 'Receive box',
      subtitle: _boxSub(box),
      children: [
        _LabeledField(label: 'Rack No.', optional: true, controller: rackC, hint: 'e.g. R-12'),
        const SizedBox(height: 12),
        _LabeledField(label: 'Bin No.', optional: true, controller: binC, hint: 'e.g. B-04'),
      ],
      cancelLabel: 'Cancel',
      confirmLabel: 'Mark received',
      onConfirm: (ctx) => Navigator.pop(ctx, true),
    );
    if (ok != true) return;
    try {
      await _api.post(ApiEndpoints.rackingReceive('${box.id}'),
          body: {'rack_no': rackC.text.trim(), 'bin_no': binC.text.trim()});
      _toast('Box ${box.boxBarcode} received');
      _setStatus('received'); // jump to the Received list so Send is one tap away
    } catch (e) {
      _toast('$e', error: true);
    }
  }

  // ── Send to Box Scanning: confirm if shipment already has a dock, else ask ──
  Future<void> _sendBox(RackingBox box) async {
    final hasDock = (box.dockNumber ?? '').trim().isNotEmpty;
    if (hasDock) {
      final ok = await _sheet<bool>(
        title: 'Send to Box Scanning?',
        subtitle: _boxSub(box),
        children: [
          Text(
            'This box leaves Racking and appears on the Box Scanning screen (Dock ${box.dockNumber}).',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
        cancelLabel: 'Cancel',
        confirmLabel: 'Yes, send',
        onConfirm: (ctx) => Navigator.pop(ctx, true),
      );
      if (ok == true) await _doSend(box, null);
    } else {
      final dock = await _askDock(box);
      if (dock != null && dock.isNotEmpty) await _doSend(box, dock);
    }
  }

  Future<String?> _askDock(RackingBox box) {
    final dockC = TextEditingController(text: box.dockNumber ?? '');
    return _sheet<String>(
      title: 'Assign dock number',
      subtitle: _boxSub(box),
      children: [
        const Text(
          'First time this shipment is sent to Box Scanning. The whole shipment will use this dock.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 14),
        _LabeledField(label: 'Dock number', controller: dockC, hint: 'e.g. D-12'),
      ],
      cancelLabel: 'Cancel',
      confirmLabel: 'Assign & send',
      onConfirm: (ctx) {
        final dock = dockC.text.trim();
        if (dock.isEmpty) {
          _toast('Dock number is required', error: true);
          return;
        }
        Navigator.pop(ctx, dock);
      },
    );
  }

  Future<void> _doSend(RackingBox box, String? dock) async {
    try {
      final res = await _api.post(
        ApiEndpoints.rackingSend('${box.id}'),
        body: {if (dock != null && dock.isNotEmpty) 'dock_number': dock},
      );
      _toast('Box ${box.boxBarcode} sent to Box Scanning');
      if (res is Map && res['dock_number'] != null) _toast('Dock ${res['dock_number']} assigned');
      _reload();
    } on ApiException catch (e) {
      // The backend returns needs_dock with HTTP 422 (first box of a shipment
      // that has no dock yet) — caught here, not as a normal response. Re-prompt.
      final data = e.data;
      if (data is Map && data['needs_dock'] == true) {
        final d = await _askDock(box);
        if (d != null && d.isNotEmpty) await _doSend(box, d);
        return;
      }
      _toast(e.message, error: true);
    } catch (e) {
      _toast('$e', error: true);
    }
  }

  String _boxSub(RackingBox box) =>
      '${box.boxBarcode}${box.shipmentId != null ? ' · ${box.shipmentId}' : ''}';

  /// Shared bottom-sheet (drawer) shell used by receive / send / dock.
  Future<T?> _sheet<T>({
    required String title,
    required String subtitle,
    required List<Widget> children,
    required String cancelLabel,
    required String confirmLabel,
    required void Function(BuildContext ctx) onConfirm,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 18),
            ...children,
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onConfirm(ctx),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('pending', 'Pending'),
      ('received', 'Received'),
      ('sent_to_box_scanning', 'Sent to Scanning'),
    ];
    return Scaffold(
      appBar: lightAppBar(
        context,
        'Racking Area',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ScanField(
                    hint: 'Scan box barcode',
                    onSubmit: (code) async {
                      try {
                        final data = await _api.get(ApiEndpoints.rackingLookup, query: {'barcode': code});
                        final m = data is Map && data['data'] is Map
                            ? Map<String, dynamic>.from(data['data'])
                            : (data is Map ? Map<String, dynamic>.from(data) : null);
                        if (m != null) _receiveBox(RackingBox.fromJson(m));
                      } catch (e) {
                        _toast('$e', error: true);
                      }
                    },
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      for (final (value, label) in filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterPill(
                            label: label,
                            selected: _status == value,
                            onTap: () => _setStatus(value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AsyncView<List<RackingBox>>(
        future: _future,
        onRetry: _reload,
        builder: (_, boxes) {
          if (boxes.isEmpty) return const Center(child: Text('No boxes.'));
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: boxes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _RackingCard(
                box: boxes[i],
                onReceive: () => _receiveBox(boxes[i]),
                onSend: () => _sendBox(boxes[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pill-style status filter (active = orange filled, inactive = white border).
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Pwa.primary : Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? Pwa.primary : Pwa.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Pwa.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// One racking box row — barcode, status badge, shipment/units/dock/rack meta,
/// and the contextual action button (Receive / Send / done).
class _RackingCard extends StatelessWidget {
  const _RackingCard({required this.box, required this.onReceive, required this.onSend});

  final RackingBox box;
  final VoidCallback onReceive;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final pending = box.status == 'pending';
    final received = box.status == 'received';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(box.boxBarcode,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                const SizedBox(width: 8),
                _StatusBadge(box.status),
              ],
            ),
            const SizedBox(height: 6),
            _meta([
              if (box.shipmentId != null) box.shipmentId!,
              if (box.fcName != null && box.fcName!.isNotEmpty) box.fcName!,
            ].join(' · ')),
            _meta('${box.totalUnits} units · Dock ${_dash(box.dockNumber)}'),
            _meta('Rack ${_dash(box.rackNo)} · Bin ${_dash(box.binNo)}'),
            if (pending || received) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: pending
                    ? FilledButton(onPressed: onReceive, child: const Text('Receive'))
                    : FilledButton(onPressed: onSend, child: const Text('Send to scanning')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _dash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  Widget _meta(String text) {
    if (text.trim().isEmpty || text == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: const TextStyle(color: Colors.black54, fontSize: 12)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'pending' => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      'received' => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      _ => (const Color(0xFFE6F8FA), const Color(0xFF0C8E9C)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Labeled text field used inside the bottom-sheet drawers, with an optional
/// "(optional)" hint matching the PWA.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.optional = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (optional)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('(optional)', style: TextStyle(color: Colors.black45, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
