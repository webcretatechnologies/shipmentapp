/// Helpers for tolerant JSON parsing (backend shapes vary).
int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
String asStr(dynamic v) => (v ?? '').toString();
bool asBool(dynamic v) => v == true || v == 1 || v == '1';

/// A shipment row (list + detail).
class Shipment {
  Shipment({
    required this.id,
    required this.shipmentId,
    required this.status,
    this.vendor,
    this.totalSkus = 0,
    this.totalUnits = 0,
    this.scannedUnits = 0,
    this.areaCode,
    this.fcName,
    this.boxesScanned = 0,
    this.appointmentDate,
  });

  final int id;
  final String shipmentId; // the FBA code
  final String status;
  final String? vendor;
  final int totalSkus;
  final int totalUnits;
  final int scannedUnits;
  final String? areaCode;
  final String? fcName; // fulfillment center (e.g. DED5) — shown under the code
  final int boxesScanned; // total_boxes_scanned — shown in the card meta
  final DateTime? appointmentDate; // shown as "Appt." in the list card

  double get progress => totalUnits == 0 ? 0 : (scannedUnits / totalUnits).clamp(0, 1);

  factory Shipment.fromJson(Map<String, dynamic> json) => Shipment(
        id: asInt(json['id']),
        shipmentId: asStr(json['shipment_id']),
        status: asStr(json['status']),
        vendor: json['vendor']?.toString(),
        totalSkus: asInt(json['total_sku'] ?? json['total_skus']),
        totalUnits: asInt(json['total_units']),
        scannedUnits: asInt(json['scanned_qty'] ?? json['scanned_units']),
        areaCode: json['area_code']?.toString(),
        fcName: (json['fc_name'] ?? json['fulfillment_center'])?.toString(),
        boxesScanned: asInt(json['total_boxes_scanned']),
        appointmentDate: DateTime.tryParse(
            (json['appointment_date'] ?? json['appointment'] ?? '').toString()),
      );
}

/// A line item / expected product within a shipment.
class ScanProduct {
  ScanProduct({
    required this.id,
    required this.merchantSku,
    required this.title,
    required this.expected,
    required this.scanned,
    this.asin,
    this.fnsku,
    this.ean,
    this.area,
  });

  final int id;
  final String merchantSku;
  final String title;
  final int expected; // effective scan target
  final int scanned;
  final String? asin;
  final String? fnsku;
  final String? ean;
  final String? area;

  bool get complete => scanned >= expected && expected > 0;

  factory ScanProduct.fromJson(Map<String, dynamic> json) => ScanProduct(
        id: asInt(json['id']),
        merchantSku: asStr(json['merchant_sku']),
        title: asStr(json['title']),
        expected: asInt(json['scan_target_qty'] ?? json['expected_qty'] ?? json['shipped']),
        scanned: asInt(json['scanned_qty']),
        asin: json['asin']?.toString(),
        fnsku: json['fnsku']?.toString(),
        ean: json['ean']?.toString(),
        area: json['area']?.toString(),
      );
}

/// A single product scan-log row (the "Scan log" tab — like the PWA).
class ScanLogEntry {
  ScanLogEntry({
    required this.merchantSku,
    required this.qty,
    this.fnsku,
    this.asin,
    this.ean,
    this.boxBarcode,
    this.userName,
    this.updatedAt,
  });

  final String merchantSku;
  final int qty;
  final String? fnsku;
  final String? asin;
  final String? ean;
  final String? boxBarcode; // null => "Not in a box yet"
  final String? userName;
  final String? updatedAt;

  factory ScanLogEntry.fromJson(Map<String, dynamic> j) => ScanLogEntry(
        merchantSku: asStr(j['merchant_sku']),
        qty: asInt(j['qty']),
        fnsku: j['fnsku']?.toString(),
        asin: j['asin']?.toString(),
        ean: (j['ean'] ?? j['external_id'])?.toString(),
        boxBarcode: j['box_barcode']?.toString(),
        userName: j['user_name']?.toString(),
        updatedAt: j['updated_at']?.toString(),
      );
}

/// A box with its packed lines (the "Boxes (packing)" tab).
class BoxLog {
  BoxLog({required this.boxBarcode, required this.qty, this.rackingLabel, this.lines = const []});
  final String boxBarcode;
  final int qty;
  final String? rackingLabel;
  final List<ScanLogEntry> lines;

  factory BoxLog.fromJson(Map<String, dynamic> j) => BoxLog(
        boxBarcode: asStr(j['box_barcode']),
        qty: asInt(j['qty_count'] ?? j['qty']),
        rackingLabel: j['racking_label']?.toString(),
        lines: ((j['products'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ScanLogEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Aggregated scan state for a shipment (`shipments/{id}/scan-state`).
class ScanState {
  ScanState({
    required this.totalScanned,
    required this.totalTarget,
    required this.boxesScanned,
    required this.boxesTotal,
    this.status = '',
    this.areaCode,
    this.products = const [],
    this.scanLog = const [],
    this.boxLog = const [],
    this.kittingComplete = true,
    this.scanAllowed = true,
    this.scanBlockHeading,
    this.scanBlockMessage,
    this.scanBlockStyle,
  });

  final int totalScanned;
  final int totalTarget;
  final int boxesScanned;
  final int boxesTotal;
  final String status;
  final String? areaCode;
  final List<ScanProduct> products; // "Expected" tab
  final List<ScanLogEntry> scanLog; // "Scan log" tab
  final List<BoxLog> boxLog; // "Boxes (packing)" tab
  final bool kittingComplete;

  // scan_access — mirrors the PWA. When scanAllowed is false the scan input is
  // hidden and a banner (heading/message, coloured by style) is shown instead
  // (e.g. shipment on HOLD, scanning complete, short-SKU pending).
  final bool scanAllowed;
  final String? scanBlockHeading;
  final String? scanBlockMessage;
  final String? scanBlockStyle; // warning | success | info

  factory ScanState.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map ? Map<String, dynamic>.from(json['totals']) : json;
    final productsRaw = (json['products'] as List?) ?? const [];
    final logRaw = (json['product_scan_log'] as List?) ?? const [];
    final boxRaw = (json['box_scan_log'] as List?) ?? const [];
    final kitting = json['kitting'] is Map ? Map<String, dynamic>.from(json['kitting']) : null;
    final ship = json['shipment'] is Map ? Map<String, dynamic>.from(json['shipment']) : null;
    final access = json['scan_access'] is Map ? Map<String, dynamic>.from(json['scan_access']) : null;
    return ScanState(
      status: asStr(ship?['status']),
      areaCode: ship?['area_code']?.toString(),
      scanAllowed: access == null ? true : access['allowed'] != false,
      scanBlockHeading: access?['heading']?.toString(),
      scanBlockMessage: access?['message']?.toString(),
      scanBlockStyle: access?['style']?.toString(),
      // Read the SAME fields the PWA renders: prefer the area-scoped values from
      // the shipment summary (area_scanned_qty / area_target_qty), then fall back
      // to the global totals. This keeps the mobile app identical to the PWA.
      totalScanned: asInt(ship?['area_scanned_qty'] ?? totals['total_scanned']),
      totalTarget: asInt(ship?['area_target_qty'] ?? totals['total_shipped'] ?? totals['total_target']),
      boxesScanned: asInt(totals['total_boxes_scanned']),
      boxesTotal: asInt(totals['total_boxes_expected']),
      products: productsRaw
          .whereType<Map>()
          .map((e) => ScanProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      scanLog: logRaw
          .whereType<Map>()
          .map((e) => ScanLogEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      boxLog: boxRaw
          .whereType<Map>()
          .map((e) => BoxLog.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      kittingComplete: kitting == null ? true : asBool(kitting['complete'] ?? kitting['kitting_complete']),
    );
  }

  /// Returns a copy with the given products — used to preserve the "Expected"
  /// list when a scan response omits products.
  ScanState withProducts(List<ScanProduct> p) => ScanState(
        totalScanned: totalScanned,
        totalTarget: totalTarget,
        boxesScanned: boxesScanned,
        boxesTotal: boxesTotal,
        status: status,
        areaCode: areaCode,
        products: p,
        scanLog: scanLog,
        boxLog: boxLog,
        kittingComplete: kittingComplete,
        scanAllowed: scanAllowed,
        scanBlockHeading: scanBlockHeading,
        scanBlockMessage: scanBlockMessage,
        scanBlockStyle: scanBlockStyle,
      );
}

/// A racking-area box.
class RackingBox {
  RackingBox({
    required this.id,
    required this.boxBarcode,
    required this.status,
    this.shipmentId,
    this.fcName,
    this.rackNo,
    this.binNo,
    this.dockNumber,
    this.totalUnits = 0,
  });

  final int id;
  final String boxBarcode;
  final String status; // pending / received / sent_to_box_scanning
  final String? shipmentId;
  final String? fcName;
  final String? rackNo;
  final String? binNo;
  final String? dockNumber;
  final int totalUnits;

  factory RackingBox.fromJson(Map<String, dynamic> json) {
    // verified shape: shipment is nested {id, shipment_id, fc_name}
    final ship = json['shipment'] is Map ? Map<String, dynamic>.from(json['shipment']) : null;
    return RackingBox(
      id: asInt(json['id']),
      boxBarcode: asStr(json['box_barcode']),
      status: asStr(json['status']),
      shipmentId: ship?['shipment_id']?.toString() ?? json['shipment_id']?.toString(),
      fcName: ship?['fc_name']?.toString() ?? json['fc_name']?.toString(),
      rackNo: json['rack_no']?.toString(),
      binNo: json['bin_no']?.toString(),
      dockNumber: json['dock_number']?.toString(),
      totalUnits: asInt(json['total_units']),
    );
  }
}
