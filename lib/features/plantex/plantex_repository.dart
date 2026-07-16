import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/plantex.dart';

/// Talks to the Plantex (PO-based vendor) endpoints — the JSON mirror of the
/// web Supplier\SupplierPlantexController. SAME rules: EAN-only scan → pack box,
/// direct short, raise invoice. See Api\Mobile\MobilePlantexController.
class PlantexRepository {
  PlantexRepository(this.api);
  final ApiClient api;

  /// Vendor's Plantex shipments. Response: {data:[summary,...]}.
  Future<List<PlantexShipment>> list({String? search}) async {
    final data = await api.get(ApiEndpoints.plantexShipments, query: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final rows = data is Map ? (data['data'] ?? []) : (data ?? []);
    return (rows as List? ?? const [])
        .whereType<Map>()
        .map((e) => PlantexShipment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Detail + items + boxes + recent scans.
  Future<PlantexDetail> detail(int id) async {
    final data = await api.get(ApiEndpoints.plantexShipment(id.toString()));
    return PlantexDetail.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
  }

  /// Accept the PO (released → accepted). Returns the refreshed summary.
  Future<PlantexShipment> accept(int id) async =>
      _summaryFrom(await api.post(ApiEndpoints.plantexAccept(id.toString())));

  /// Pack scanned EAN lines into a box and seal it.
  /// Throws ApiException with `.data['message']` on 422 (unknown box, exceeds qty…).
  Future<PlantexShipment> packBox({
    required int id,
    required String boxBarcode,
    required List<({String ean, int qty})> lines,
  }) async {
    final res = await api.post(ApiEndpoints.plantexPackBox(id.toString()), body: {
      'box_barcode': boxBarcode,
      'lines': [
        for (final l in lines) {'ean': l.ean, 'qty': l.qty},
      ],
    });
    return _summaryFrom(res);
  }

  /// Remove (minus) units of an EAN from a box, one-by-one by default.
  Future<PlantexShipment> removeUnit({
    required int id,
    required String boxBarcode,
    required String ean,
    int qty = 1,
  }) async {
    final res = await api.post(ApiEndpoints.plantexRemoveUnit(id.toString()), body: {
      'box_barcode': boxBarcode,
      'ean': ean,
      'qty': qty,
    });
    return _summaryFrom(res);
  }

  /// Direct short close (no approval).
  Future<PlantexShipment> markShort({required int id, String? reason}) async {
    final res = await api.post(ApiEndpoints.plantexMarkShort(id.toString()), body: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return _summaryFrom(res);
  }

  /// Raise invoice — dispatch details + invoice file (multipart).
  Future<PlantexShipment> raiseInvoice({
    required int id,
    required Map<String, dynamic> dispatch,
    String? invoiceFilePath,
  }) async {
    final res = await api.postMultipart(
      ApiEndpoints.plantexRaiseInvoice(id.toString()),
      fields: dispatch,
      files: {
        if (invoiceFilePath != null && invoiceFilePath.isNotEmpty)
          'invoice_file': invoiceFilePath,
      },
    );
    return _summaryFrom(res);
  }

  PlantexShipment _summaryFrom(dynamic res) {
    final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    final s = map['shipment'] is Map ? Map<String, dynamic>.from(map['shipment']) : map;
    return PlantexShipment.fromJson(s);
  }
}
