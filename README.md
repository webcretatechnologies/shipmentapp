# Plantex Mobile (Flutter)

Native Android + iOS apps for the **Plantex Shipment Module**, built from one Flutter codebase with **two flavors**:

| Flavor | App | Audience | Default API host |
|---|---|---|---|
| `shipment` | **Plantex Warehouse** | Internal warehouse staff | `https://plantex.work` |
| `supplier` | **Plantex Vendor** | Suppliers / vendors | `https://supplier.plantex.work` |

It talks to the existing Laravel backend's mobile API (`/api/v1/mobile/*`, Sanctum bearer tokens). No business logic is duplicated — the app is a thin, attractive client over the same endpoints the PWA uses.

> ⚠️ This repo currently contains the **Dart source only** (`lib/`, `pubspec.yaml`, configs). The native `android/` and `ios/` folders are NOT committed — generate them once with `flutter create .` (see Setup). That command fills in the platform shells without modifying `lib/`.

---

## Setup (first time)

```bash
# 1. Install Flutter SDK (stable channel): https://docs.flutter.dev/get-started/install
flutter --version          # 3.22+ recommended

# 2. From this folder, materialize the native platform folders (keeps lib/ untouched)
flutter create . --org work.plantex --platforms=android,ios --project-name plantex_mobile

# 3. Install packages
flutter pub get

# 4. Run a flavor (compile-time selection via --dart-define)
flutter run --dart-define=APP_FLAVOR=shipment
flutter run --dart-define=APP_FLAVOR=supplier

# point at a different backend (e.g. local/staging):
flutter run --dart-define=APP_FLAVOR=shipment --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` is the Android emulator's alias for the host machine's `localhost`.

### Building releases
```bash
flutter build apk   --dart-define=APP_FLAVOR=shipment --release
flutter build ipa   --dart-define=APP_FLAVOR=supplier --release
```
To give each flavor a distinct **app id / icon** (so both can be installed side-by-side), add Gradle product flavors (`android/app/build.gradle`) and iOS schemes — see `docs/FLAVORS.md` (TODO) or split into true `--flavor` builds. The Dart side already branches on `AppFlavor`.

---

## Architecture

```
lib/
  main.dart                       # entrypoint → reads flavor, boots App
  app/
    app.dart                      # MaterialApp.router + theme + providers
    app_config.dart               # flavor + base URL (from --dart-define)
    flavor.dart                   # AppFlavor enum + per-flavor config (title, accent, modules)
    router.dart                   # go_router routes + auth redirect
  core/
    api/
      api_client.dart             # Dio wrapper: base url, bearer token, error mapping
      api_endpoints.dart          # every /api/v1/mobile/* path (single source of truth)
    auth/
      auth_controller.dart        # ChangeNotifier: login / me / logout, holds session
    storage/
      token_storage.dart          # flutter_secure_storage (token persistence)
    models/
      auth_models.dart            # User, AuthSession, Capabilities
      shipment.dart               # Shipment, ScanState, ScanProduct
      dashboard_counts.dart       # counts for dashboard cards
    theme/app_theme.dart          # light/dark theme, brand colors
    widgets/                      # shared UI (scanner sheet, cards, async views)
  features/
    auth/login_screen.dart
    dashboard/dashboard_screen.dart
    shipments/                    # list + scan (the core flow — implemented)
    racking/  box_scanning/  kitting/  short_sku/  short_box/   # internal modules (stubs + API hooks)
    supplier/                     # supplier dashboard + invoice flow (stubs + API hooks)
```

**State:** `provider` (ChangeNotifier) — simple, robust. **HTTP:** `dio`. **Routing:** `go_router`. **Token:** `flutter_secure_storage`. **Scanning:** `mobile_scanner` (camera) + manual text entry fallback (USB/Bluetooth ring scanners type into the field).

---

## Backend API map (`/api/v1/mobile`, Sanctum `auth:sanctum`)

Mirrors `Modules/Shipment/routes/api.php`. See `lib/core/api/api_endpoints.dart`.

| Area | Method · Path |
|---|---|
| Auth | `POST auth/login` · `GET auth/me` · `POST auth/logout` |
| Shipments | `GET shipments` · `GET shipments/{id}` · `GET shipments/{id}/scan-state` |
| Scan | `POST shipments/scan` · `POST shipments/save-label` · `GET shipments/next-box-barcode` |
| Kitting | `GET kitting/shipments` (+ combo workflow endpoints) |
| Box scanning / loading | `GET box-scanning/shipments` · `GET shipments/{id}/box-loading-state` · `POST shipments/{id}/box-scan-for-loading` · `POST shipments/{id}/remove-hold-sku` |
| Short SKU | `GET shipments/{id}/short-sku` · `POST shipments/{id}/short-sku` |
| Short Box | `GET shipments/{id}/short-box` · `POST shipments/{id}/short-box` |
| Racking | `GET racking` · `GET racking/lookup` · `POST racking/{id}/receive` · `POST racking/{id}/send` |
| Dispatch / stock | `GET shipments/{id}/dispatch` · `POST shipments/{id}/mark-invoiced` · stock-move endpoints |

### Backend endpoints (all now implemented in `routes/api.php`)
The backend ships **dedicated mobile controllers** — no admin/web controller was modified:
- `MobileAuthController` (auth), `MobileShipmentScanController` (shipments/scan/box/kitting-list), `MobileWarehouseController` (racking/short-sku/short-box) — existing.
- `MobileDashboardController` — `dashboard/counts` (new).
- `MobileKittingController` — `shipments/{id}/kitting`, `kitting/entry/{id}/hard-bundle`, `shipments/{id}/kitting/merge` (new, self-contained).
- `MobileSupplierController` — `supplier/shipments/{id}/finance`, `…/send-to-finance`, `…/seal-truck`, `supplier/purchase-orders`, `…/{id}/pdf` (new).

Vendor isolation is automatic: a vendor logs in via the same `auth/login` and `ShipmentData`'s `vendorAssigned` global scope filters every query to their `assigned_vendor_id`.

---

## Status

**Implemented end-to-end against verified JSON shapes:** flavors, theming, secure-token auth, dashboard + live counts, shipments list, product-scan (camera + manual → `scan`, live `scan-state`), racking (receive/rack/send), box-scanning/loading, kitting (detail + hard-bundle + merge), short-sku, short-box, supplier invoice (file upload) + seal-truck, purchase orders.

**Verify against live JSON:** the warehouse-list/scan-state/scan and racking shapes were read from the controllers and matched; box-loading/short-form inner keys follow the documented shapes — do a quick pass against a live response if any field reads blank.

**Next (polish):** native flavor configs for distinct app ids/icons, offline scan retry queue, push notifications.

See `Modules/Shipment/reference_shipment_module_architecture.md` in the backend repo for the full server-side flow.
