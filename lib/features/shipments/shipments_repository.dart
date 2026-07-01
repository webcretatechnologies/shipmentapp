import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/shipment.dart';

/// Talks to the shipment + scan endpoints.
class ShipmentsRepository {
  ShipmentsRepository(this.api);
  final ApiClient api;

  List<Shipment> _parseList(dynamic data) {
    // Backend mobile lists return {items:[...], pagination:{...}}; also accept
    // {data:[...]} / {shipments:[...]} / a bare list for resilience.
    final list = data is Map
        ? (data['items'] ?? data['data'] ?? data['shipments'] ?? [])
        : data;
    return (list as List? ?? [])
        .whereType<Map>()
        .map((e) => Shipment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Shipment>> list({String? search}) async {
    final data = await api.get(ApiEndpoints.shipments, query: {
      if (search != null && search.isNotEmpty) 'search': search,
      'per_page': 50,
    });
    return _sortForList(_parseList(data));
  }

  /// Actively-scanning shipments first, then the rest in API order, HOLD last.
  /// Stable within each group (preserves the backend's latest-first order).
  List<Shipment> _sortForList(List<Shipment> items) {
    int rank(String status) {
      final s = status.toLowerCase();
      if (s.contains('hold')) return 2; // hold at the bottom
      if (s.contains('scan') || s.contains('progress') || s.contains('released')) return 0; // active first
      return 1;
    }

    final indexed = items.asMap().entries.toList()
      ..sort((a, b) {
        final r = rank(a.value.status).compareTo(rank(b.value.status));
        return r != 0 ? r : a.key.compareTo(b.key); // stable tie-break
      });
    return indexed.map((e) => e.value).toList();
  }

  Future<List<Shipment>> kittingShipments() async =>
      _parseList(await api.get(ApiEndpoints.kittingShipments));

  Future<List<Shipment>> boxScanningShipments() async =>
      _parseList(await api.get(ApiEndpoints.boxScanningShipments));

  Future<ScanState> scanState(int id) async {
    // ApiClient already unwraps the {success,data} envelope, so `data` is the
    // scan-state payload itself.
    final data = await api.get(ApiEndpoints.scanState(id.toString()),
        query: {'include': 'products'});
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final state = map['scan_state'] is Map ? Map<String, dynamic>.from(map['scan_state']) : map;
    return ScanState.fromJson(state);
  }

  /// Sends a product/box barcode for a shipment. Returns the raw response map so
  /// the UI can read success/message + routed_to (box) + refreshed scan_state.
  Future<Map<String, dynamic>> scan({
    required String shipmentCode,
    required String barcode,
  }) async {
    final data = await api.post(ApiEndpoints.scan, body: {
      'shipment_id': shipmentCode,
      'barcode': barcode,
    });
    return data is Map ? Map<String, dynamic>.from(data) : {'success': false};
  }
}
