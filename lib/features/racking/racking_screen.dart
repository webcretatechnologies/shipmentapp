import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/scan_field.dart';

/// Racking Area (spec section 4): list boxes, receive a box, assign rack/bin,
/// send to box scanning. Uses GET racking, POST racking/{id}/receive|send,
/// GET racking/lookup.
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

  Future<void> _action(RackingBox box, String action, {String? rack, String? bin}) async {
    try {
      final path =
          action == 'receive' ? ApiEndpoints.rackingReceive('${box.id}') : ApiEndpoints.rackingSend('${box.id}');
      await _api.post(path, body: {
        if (rack != null) 'rack_no': rack,
        if (bin != null) 'bin_no': bin,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Box ${box.boxBarcode} ${action}d')));
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade600));
      }
    }
  }

  Future<void> _receiveWithRack(RackingBox box) async {
    final rackC = TextEditingController(text: box.rackNo ?? '');
    final binC = TextEditingController(text: box.binNo ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Assign rack — ${box.boxBarcode}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: rackC, decoration: const InputDecoration(labelText: 'Rack No')),
            const SizedBox(height: 12),
            TextField(controller: binC, decoration: const InputDecoration(labelText: 'Bin No')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Receive')),
        ],
      ),
    );
    if (ok == true) _action(box, 'receive', rack: rackC.text.trim(), bin: binC.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Racking Area'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ScanField(
                  hint: 'Scan box barcode',
                  onSubmit: (code) async {
                    try {
                      final data = await _api.get(ApiEndpoints.rackingLookup, query: {'barcode': code});
                      final m = data is Map && data['data'] is Map
                          ? Map<String, dynamic>.from(data['data'])
                          : (data is Map ? Map<String, dynamic>.from(data) : null);
                      if (m != null) _receiveWithRack(RackingBox.fromJson(m));
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade600));
                      }
                    }
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: ['pending', 'received', 'sent_to_box_scanning'].map((s) {
                    final sel = _status == s;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s.replaceAll('_', ' ')),
                        selected: sel,
                        onSelected: (_) {
                          _status = s;
                          _reload();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
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
              itemBuilder: (_, i) {
                final b = boxes[i];
                return Card(
                  child: ListTile(
                    title: Text(b.boxBarcode, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if (b.shipmentId != null) b.shipmentId,
                      if (b.rackNo != null) 'Rack ${b.rackNo}',
                      if (b.binNo != null) 'Bin ${b.binNo}',
                      b.status.replaceAll('_', ' '),
                    ].join(' · ')),
                    trailing: b.status == 'pending'
                        ? FilledButton(onPressed: () => _receiveWithRack(b), child: const Text('Receive'))
                        : b.status == 'received'
                            ? OutlinedButton(onPressed: () => _action(b, 'send'), child: const Text('Send'))
                            : const Icon(Icons.check_circle, color: Color(0xFF1B9C4A)),
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
