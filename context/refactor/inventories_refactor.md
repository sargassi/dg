# Inventories Refactor Proposal

## Context

The Inventories module tracks stock across warehouses and locations. It handles:
- Live/historical stock lookup
- Inbound receipts (`Itemin`), outbound shipments (`Itemout`), transfers (`Itemmovement`)
- Bulk Excel imports (inbound + outbound)
- QR lookup and label printing
- Warehouse/location management

Key entry points: `InventoriesController` (22 actions, ~648 lines), `IteminsController`, `ItemoutsController`, `AppController` (mobile), `API::V1::Inventories`.

## Goals

1. Fix critical bugs preventing correct stock operations.
2. Split the God controller into focused, single-responsibility controllers.
3. Eliminate duplicated logic across controllers, services, and import pipelines.
4. Unify movement creation across web, mobile, and API entry points.
5. Improve test coverage and add model-level safety guards.

---

## Phase 0 — Critical P0 bugs (done)

### 0.1 MovementBuilder crashes preview→confirm flow

**File**: `app/services/movement_builder.rb`
**Problem**: `header_params` and `build_details` called `@params.to_unsafe_h`, but `IteminsController#confirm` passes a `HashWithIndifferentAccess` from `session[:itemin_preview]`. `HashWithIndifferentAccess` does not define `to_unsafe_h`, causing `NoMethodError` crash.
**Fix**: Normalize `@params` in `initialize` via `(params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access`. All subsequent methods use `@params` directly without calling `to_unsafe_h`.

### 0.2 AppController#move_products — no stock availability check

**File**: `app/controllers/app_controller.rb`
**Problem**: Unlike `ItemoutsController` and the API `transfer` endpoint, `move_products` did not validate that the source has sufficient quantity. Allowed negative stock.
**Fix**: Added `StockLevel` query to check available quantity per gencode/warehouse/location before creating movements. Shows alert if quantity exceeds available.

### 0.3 ItemoutsController#confirm — didn't use MovementBuilder

**File**: `app/controllers/itemouts_controller.rb`
**Problem**: Manually built `Itemout` and details instead of using `MovementBuilder`. Bypassed default application (warehouse, location, operation type), potentially leaving `operationtype_id: nil` on outbound details.
**Fix**: Now uses `MovementBuilder.new(Itemout, @params).build`, matching `IteminsController#confirm`.

### 0.5 Itemmovement missing source_warehouse_id validation

**File**: `app/models/itemmovement.rb`
**Problem**: `validates :dest_warehouse_id, presence: true` existed but no validation for `source_warehouse_id`. DB allowed null — movements could be created without a source.
**Fix**: Added `validates :source_warehouse_id, presence: true`.

---

## Phase 1 — God controller split

**File**: `app/controllers/inventories_controller.rb` (22 actions, ~648 lines)

Split into focused controllers:

### 1.1 InventoryStockController

Actions: `index`, `export_xlsx`, `autocomplete`, `lookup_by_qr`, `seleziona`, `prepare_carico`
Purpose: Stock querying, lookup, and item selection.

### 1.2 InventoryImportController

Actions: `import`, `import_parse`, `import_update_row`, `import_delete_row`, `import_verify`, `import_confirm`, `import_summary`, `import_cancel`
Purpose: Bulk Excel import pipeline for movements.

### 1.3 InventoryMovementsController

Actions: `dashboard`, `movements`, `movement_label`, `movement_modal`
Purpose: Movement log display, PDF labels, modal details.

### Routes

Move from scattered manual routes under `scope '/inventories'` to proper RESTful resources with collection routes.

---

## Phase 2 — Extract shared logic

### 2.1 InventoryStockQuery object

**Problem**: `index` and `export_xlsx` share ~60% identical query logic (historical vs live branch, warehouse/collection/text filters, gencode grouping).
**Fix**: Extract to `InventoryStockQuery` accepting params and returning a base scope + results.

### 2.2 MovementWorkflow concern

**Problem**: `IteminsController` and `ItemoutsController` implement nearly identical `create → preview → confirm` flows using session-based state management.
**Fix**: Extract a `MovementWorkflow` controller concern handling build_from_session, store_to_session, confirm_and_create. Each controller provides movement_class, inventory_service_class, detail_key, redirect_path.

### 2.3 Merge CreateInventoriesFromItemin + Itemout + Itemmovement

**Files**: `app/services/create_inventories_from_itemin.rb`, `create_inventories_from_itemout.rb`, `create_inventories_from_itemmovement.rb`
**Problem**: ~80% identical — both iterate details, create `Inventory` rows, adjust `StockLevel`. Only difference: Itemin sets positive delta + QR codes; Itemout sets negative delta, no QR. Itemmovement creates two records (source + destination) and adjusts two `StockLevel`s.
**Fix**: Single `InventoryCreator` service handling all three movement types. All callers (controllers, API, import services) now use `InventoryCreator.new.call(movement)`.
**Status**: Done.

### 2.4 MovementValidations concern

**Problem**: Identical `at_least_one_detail` validation duplicated in `Itemin`, `Itemout`, `Itemmovement` models.
**Fix**: Extract to `MovementValidations` concern.

---

## Phase 3 — Unify movement creation

### 3.1 AppController and MovementWorkflow delegate to shared service

**Problem**: `in_warehouse` and `out_warehouse` duplicate the same model-building + inventory-creation logic as the web controllers, but inline instead of calling shared services.
**Fix**: Extract a generic `MovementCreationService` that builds via `MovementBuilder`, validates, saves, and calls `InventoryCreator`. Used by `AppController#in_warehouse` / `#out_warehouse` and by `MovementWorkflow#confirm` (used by `IteminsController` / `ItemoutsController`). Removed the now-unused `inventory_service:` option from `MovementWorkflow`.
**Status**: Done.

### 3.2 Extract SpreadsheetImportBase

**Files**: `app/services/import_inventory_service.rb` (205 lines), `app/services/import_itemout_service.rb` (159 lines)
**Problem**: Both implement identical parse/save structure with header detection, warehouse/collection resolution, caching, error handling. Differ only in validate_row and detail construction.
**Fix**: Extract `app/services/spreadsheet_import_base.rb` with the shared parse skeleton, case-insensitive `find_header_row`, the `cell(row, *keys)` lookup helper, `find_or_create_warehouse`/`find_or_create_collection`, and `extract_error`. Both services now subclass it; `save` stays subclass-specific per service (inventory: single movement, `_warehouse_id`/`_collection_id` resolved at parse via `after_row` + `extra_metadata`; itemout: grouped-by-date Itemouts, resolution at save).
**Status**: Done.

### 3.3 Consistent itemcode across entry points

**Problem**: Five entry points populate `itemcode` on inventory records differently (some use gencode, some use actual itemcode).
**Fix**: Normalize to always use the Item's actual `itemcode`. Set in a single place (inventory creation service). `InventoryCreator` already writes `itemcode: item&.itemcode || detail.itemcode` on the Inventory record; the entry points that built detail records with gencode were normalized too (API inbound/outbound/transfer, `AppController#in_warehouse` prefill, `ItemoutsController#new` prefill, `Archive::ItemsController#import_single`).
**Status**: Done.

---

## Phase 4 — Import pipeline polish

### 4.1 Fix race condition in ImportInventoryService#save

**Problem**: Item resolved during parse, re-looked up via `Item.find` in save. If deleted within cache window, crashes transaction.
**Fix**: Use `Item.find_by` and skip missing items.
**Status**: Done (implemented with the 2.3/3.x unification; covered by `import_inventory_service_test.rb`).

### 4.2 Backport mainware import improvements

**Status**: Partial. Already present in the inventory pipeline: grouped summary with invalid/skipped/errors tables, row-level validation with visual feedback, new-vs-existing (green/amber) indicators, loader with cancel. Backported in this phase:
- **Import audit log**: `inventory_import#import_confirm` now writes an `ImportLog` (created/invalid/skipped counts, created_ids, error_details, status completed/failed).
- **Failed-row export**: `inventory_import#import_failed_rows` streams an XLSX of invalid + skipped rows; link shown on the summary page.
Remaining larger buildouts (not done): bulk collection assignment with quick-create, column visibility toggle, async progress with cancel.

### 4.3 Fix dead link in dashboard

**File**: `app/views/inventories/dashboard.html.erb`
**Problem**: `<a href="#">` for "Variazione Magazzino".
**Fix**: Link to `app_move_products_path`.
**Status**: Done (already linked to `app_move_products_path`).

### 4.4 Fix route nesting

**Problem**: `resources :warehouses` is inside `scope '/inventories'`, making URLs like `/inventories/warehouses`.
**Fix**: Move warehouse/location routes outside the inventories scope. Added 301 redirects for the old `/inventories/warehouses/*` and `/inventories/locations/*` URLs and updated the hardcoded fetch in `qr_scanner_controller.js` (`/warehouses/lookup_by_qr`).
**Status**: Done.

---

## Phase 5 — Test coverage + model hardening

### 5.1 Service-level tests

Zero tests for: `MovementBuilder`, `CreateInventoriesFromItemin/Itemout/Itemmovement`, `ImportInventoryService`, `ImportItemoutService`, `QrParser`, `CreateQrService`.

### 5.2 Controller action tests

15 custom actions in InventoriesController untested: dashboard, seleziona, autocomplete, movements, export_xlsx, import pipeline (8), QR actions, lookup_by_qr, movement_label, movement_modal.

### 5.3 Inventory model validations

```ruby
validates :gencode, presence: true
validates :qtyavailable, numericality: true
validates :warehouse_id, presence: true
validate :single_movement_origin  # itemin_id, itemout_id, itemmovement_id are mutually exclusive
```

### 5.4 StockLevel negative guard

Add model-level guard against negative quantities in `adjust_qty!`.

---

## Risks and considerations

- **Session-based state**: Import pipeline and create→preview→confirm flow rely on session/cache. Controller extraction must preserve same keys.
- **Mobile API consumers**: API (`/api/v1/inventories`) and `AppController` serve mobile clients. Refactoring must maintain backward-compatible API responses.
- **Zero service tests**: Extract logic alongside tests. Don't refactor untested code without adding coverage.
- **Itemmovement has no dedicated controller**: Creation split between `AppController`, `API`, `Archive::ItemsController`. Consider adding one.

---

## Suggested execution order

1. Phase 0 — fix P0 bugs (done)
2. Phase 2.3 + 2.4 — merge duplicated services/models (low-risk, high-payoff)
3. Phase 1 — split God controller
4. Phase 2.1 + 2.2 — extract shared queries and workflow concern
5. Phase 3.2 + 3.3 — unify spreadsheet imports and itemcode normalization (done)
6. Phase 4 — import pipeline polish (done: 4.1, 4.3, 4.4; 4.2 partial)
7. Phase 5 — tests and model hardening
