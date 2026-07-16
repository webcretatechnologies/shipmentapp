import 'shipment.dart' show asInt, asStr, asBool;

/// A Plantex (PO-based) vendor shipment. Mirrors MobilePlantexController::summary().
class PlantexShipment {
  PlantexShipment({
    required this.id,
    required this.shipmentCode,
    required this.status,
    required this.statusLabel,
    this.poNumber,
    this.vendorName,
    this.fcName,
    this.isShort = false,
    this.totalItems = 0,
    this.totalQty = 0,
    this.scannedQty = 0,
    this.totalBoxes = 0,
    this.closedBoxes = 0,
    this.appointmentDate,
    this.invoiceApproved = false,
    this.transporterName,
    this.transporterGst,
    this.vehicleNo,
    this.driverName,
    this.driverNo,
    this.dispatchNotes,
    this.invoiceFileUrl,
    this.invoiceRaisedAt,
  });

  final int id;
  final String shipmentCode;
  final String status;
  final String statusLabel;
  final String? poNumber;
  final String? vendorName;
  final String? fcName;
  final bool isShort;
  final int totalItems;
  final int totalQty;
  final int scannedQty;
  final int totalBoxes;
  final int closedBoxes;
  final String? appointmentDate;
  final bool invoiceApproved;

  // Raised-invoice dispatch details (from the `dispatch` block).
  final String? transporterName;
  final String? transporterGst;
  final String? vehicleNo;
  final String? driverName;
  final String? driverNo;
  final String? dispatchNotes;
  final String? invoiceFileUrl;
  final String? invoiceRaisedAt;

  double get progress => totalQty == 0 ? 0 : (scannedQty / totalQty).clamp(0, 1);
  bool get isAccepted => status != 'released';
  bool get isInvoiced => status == 'invoiced' || status == 'closed';
  bool get isClosed => status == 'closed';

  factory PlantexShipment.fromJson(Map<String, dynamic> j) => PlantexShipment(
        id: asInt(j['id']),
        shipmentCode: asStr(j['shipment_code']),
        status: asStr(j['status']),
        statusLabel: asStr(j['status_label']),
        poNumber: j['po_number']?.toString(),
        vendorName: j['vendor_name']?.toString(),
        fcName: j['fc_name']?.toString(),
        isShort: asBool(j['is_short']),
        totalItems: asInt(j['total_items']),
        totalQty: asInt(j['total_qty']),
        scannedQty: asInt(j['scanned_qty']),
        totalBoxes: asInt(j['total_boxes']),
        closedBoxes: asInt(j['closed_boxes']),
        appointmentDate: j['appointment_date']?.toString(),
        invoiceApproved: asBool(j['invoice_approved']),
        transporterName: _disp(j, 'transporter_name'),
        transporterGst: _disp(j, 'transporter_gst'),
        vehicleNo: _disp(j, 'vehicle_no'),
        driverName: _disp(j, 'driver_name'),
        driverNo: _disp(j, 'driver_no'),
        dispatchNotes: _disp(j, 'dispatch_notes'),
        invoiceFileUrl: _disp(j, 'invoice_file_url'),
        invoiceRaisedAt: _disp(j, 'invoice_raised_at'),
      );

  /// Pull a value from the nested `dispatch` block (null-safe).
  static String? _disp(Map<String, dynamic> j, String key) {
    final d = j['dispatch'];
    return d is Map ? d[key]?.toString() : null;
  }
}

/// A PO line item (EAN → qty). From the `items` array on show().
class PlantexItem {
  PlantexItem({
    required this.id,
    required this.merchantSku,
    required this.itemName,
    required this.ean,
    required this.qty,
    required this.scannedQty,
    required this.remaining,
  });

  final int id;
  final String merchantSku;
  final String itemName;
  final String ean;
  final int qty;
  final int scannedQty;
  final int remaining;

  bool get complete => scannedQty >= qty && qty > 0;

  factory PlantexItem.fromJson(Map<String, dynamic> j) => PlantexItem(
        id: asInt(j['id']),
        merchantSku: asStr(j['merchant_sku']),
        itemName: asStr(j['item_name']),
        ean: asStr(j['ean']),
        qty: asInt(j['qty']),
        scannedQty: asInt(j['scanned_qty']),
        remaining: asInt(j['remaining']),
      );
}

/// A generated box. From the `boxes` array on show().
class PlantexBox {
  PlantexBox({
    required this.id,
    required this.boxBarcode,
    required this.seq,
    required this.status,
    required this.scannedQty,
  });

  final int id;
  final String boxBarcode;
  final int seq;
  final String status; // open | closed
  final int scannedQty;

  bool get isClosed => status == 'closed';

  factory PlantexBox.fromJson(Map<String, dynamic> j) => PlantexBox(
        id: asInt(j['id']),
        boxBarcode: asStr(j['box_barcode']),
        seq: asInt(j['seq']),
        status: asStr(j['status']),
        scannedQty: asInt(j['scanned_qty']),
      );
}

/// A scan-log row. From the `scans` array on show().
class PlantexScan {
  PlantexScan({required this.sku, required this.ean, required this.qty, this.boxId, this.at});
  final String sku;
  final String ean;
  final int qty;
  final int? boxId;
  final String? at;

  factory PlantexScan.fromJson(Map<String, dynamic> j) => PlantexScan(
        sku: asStr(j['sku']),
        ean: asStr(j['ean']),
        qty: asInt(j['qty']),
        boxId: j['box_id'] == null ? null : asInt(j['box_id']),
        at: j['at']?.toString(),
      );
}

/// Full detail payload returned by show().
class PlantexDetail {
  PlantexDetail({
    required this.shipment,
    required this.items,
    required this.boxes,
    required this.scans,
  });

  final PlantexShipment shipment;
  final List<PlantexItem> items;
  final List<PlantexBox> boxes;
  final List<PlantexScan> scans;

  List<PlantexBox> get openBoxes => boxes.where((b) => !b.isClosed).toList();
  List<PlantexBox> get closedBoxes => boxes.where((b) => b.isClosed).toList();

  factory PlantexDetail.fromJson(Map<String, dynamic> j) {
    List<T> arr<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => f(Map<String, dynamic>.from(e)))
            .toList();
    return PlantexDetail(
      shipment: PlantexShipment.fromJson(
          Map<String, dynamic>.from(j['shipment'] as Map? ?? const {})),
      items: arr('items', PlantexItem.fromJson),
      boxes: arr('boxes', PlantexBox.fromJson),
      scans: arr('scans', PlantexScan.fromJson),
    );
  }
}
