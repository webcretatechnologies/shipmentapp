import 'shipment.dart';

/// Counts for the dashboard cards (spec section 2).
/// Backed by `GET /api/v1/mobile/dashboard/counts` (add it server-side — see api.php).
class DashboardCounts {
  DashboardCounts({
    this.shipments = 0,
    this.racking = 0,
    this.boxScanning = 0,
    this.shortSku = 0,
    this.shortBox = 0,
    this.kitting = 0,
    this.invoices = 0,
    this.purchaseOrders = 0,
    this.active = 0,
    this.complete = 0,
    this.pending = 0,
  });

  final int shipments;
  final int racking;
  final int boxScanning;
  final int shortSku;
  final int shortBox;
  final int kitting;
  final int invoices;
  final int purchaseOrders;

  // Top stat strip (shipment lifecycle). 0 when the API omits them.
  final int active;
  final int complete;
  final int pending;

  bool get hasStrip => active > 0 || complete > 0 || pending > 0;

  int forModule(String key) {
    switch (key) {
      case 'shipments':
        return shipments;
      case 'racking':
        return racking;
      case 'boxScanning':
        return boxScanning;
      case 'shortSku':
        return shortSku;
      case 'shortBox':
        return shortBox;
      case 'kitting':
        return kitting;
      case 'invoices':
        return invoices;
      case 'purchaseOrders':
        return purchaseOrders;
      default:
        return 0;
    }
  }

  factory DashboardCounts.fromJson(Map<String, dynamic> json) => DashboardCounts(
        shipments: asInt(json['shipments']),
        racking: asInt(json['racking']),
        boxScanning: asInt(json['box_scanning']),
        shortSku: asInt(json['short_sku']),
        shortBox: asInt(json['short_box']),
        kitting: asInt(json['kitting']),
        invoices: asInt(json['invoices']),
        purchaseOrders: asInt(json['purchase_orders']),
        active: asInt(json['active']),
        complete: asInt(json['complete']),
        pending: asInt(json['pending']),
      );
}
