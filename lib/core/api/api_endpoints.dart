/// Single source of truth for the backend mobile API paths.
/// Mirrors `Modules/Shipment/routes/api.php` (prefix already on the Dio base URL).
class ApiEndpoints {
  // ---- App config (public — logo + name from admin settings) ----
  static const appConfig = '/app-config';

  // ---- Auth ----
  static const login = '/auth/login';
  static const me = '/auth/me';
  static const logout = '/auth/logout';

  // ---- Dashboard ----
  static const dashboardCounts = '/dashboard/counts';

  // ---- Shipments ----
  static const shipments = '/shipments';
  static String shipment(String id) => '/shipments/$id';
  static String scanState(String id) => '/shipments/$id/scan-state';

  // ---- Scanning ----
  static const scan = '/shipments/scan';
  static const saveLabel = '/shipments/save-label';
  static const nextBoxBarcode = '/shipments/next-box-barcode';

  // ---- Kitting (combo) ----
  static const kittingShipments = '/kitting/shipments';
  static String kittingDetail(String id) => '/shipments/$id/kitting';
  static String kittingHardBundle(String entryId) => '/kitting/entry/$entryId/hard-bundle';
  static String kittingMerge(String id) => '/shipments/$id/kitting/merge';

  // ---- Supplier / vendor ----
  static String supplierFinance(String id) => '/supplier/shipments/$id/finance';
  static String supplierSendToFinance(String id) => '/supplier/shipments/$id/send-to-finance';
  static String supplierSealTruck(String id) => '/supplier/shipments/$id/seal-truck';
  static String supplierDispatch(String id) => '/supplier/shipments/$id/dispatch';
  static const supplierPurchaseOrders = '/supplier/purchase-orders';
  static String supplierPoDetail(String id) => '/supplier/purchase-orders/$id';
  static String supplierPoPdf(String id) => '/supplier/purchase-orders/$id/pdf';

  // ---- Box scanning / loading ----
  static const boxScanningShipments = '/box-scanning/shipments';
  static String boxLoadingState(String id) => '/shipments/$id/box-loading-state';
  static String boxScanForLoading(String id) => '/shipments/$id/box-scan-for-loading';
  static String removeHoldSku(String id) => '/shipments/$id/remove-hold-sku';

  // ---- Short SKU ----
  static String shortSku(String id) => '/shipments/$id/short-sku';

  // ---- Short Box ----
  static String shortBox(String id) => '/shipments/$id/short-box';

  // ---- Racking ----
  static const racking = '/racking';
  static const rackingLookup = '/racking/lookup';
  static String rackingReceive(String id) => '/racking/$id/receive';
  static String rackingSend(String id) => '/racking/$id/send';

  // ---- Dispatch / stock move ----
  static String dispatch(String id) => '/shipments/$id/dispatch';
  static String markInvoiced(String id) => '/shipments/$id/mark-invoiced';
  static const stockmoveWarehouses = '/stockmove-warehouses';
}
