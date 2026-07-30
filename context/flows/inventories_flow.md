# Inventories Flow

## Module purpose

The Inventories module tracks stock across warehouses and locations. It handles:
- live/historical stock lookup (`inventories#index`)
- inbound receipts (`Itemin`)
- outbound shipments (`Itemout`)
- transfers between warehouses/locations (`Itemmovement`)
- bulk imports of movements from Excel
- QR lookup and label printing
- warehouse/location management

The `InventoriesController` is the central hub. `IteminsController` and `ItemoutsController` handle the dedicated movement screens. `Itemmovement` records are created via the mobile `AppController` and the `API::V1::Inventories` endpoints.

All actions require the appropriate ability: `manage_inventory`, `manage_itemins`, `manage_itemouts`, `manage_warehouses`, `manage_locations`.

## Stock model

- `StockLevel` is the current snapshot: one row per `gencode + warehouse + location`, with `current_qty`.
- `Inventory` is the event log: one row per movement event (in/out/transfer), linking to `Itemin`/`Itemout`/`Itemmovement`.
- QR codes are generated for `Item` (gencode), `Warehouse` (id + code), and `Location` (warehouse_id + id + code).
- A QR on a `IteminsDetail` encodes the gencode plus the detail id, so scanning can suggest the exact inbound warehouse/location.

## Subsections

### 1. Dashboard — `inventories/dashboard`

- Entry point with three main action cards:
  - **IN** → `app_in_warehouse_path`
  - **OUT** → `app_out_warehouse_path`
  - **VAR** → `app_move_products_path`
- Card groups:
  - **Magazzino**: Ricerca Magazzino, Seleziona Articoli, Nuovo Articolo, Importa da Excel
  - **Movimenti Magazzino**: Aggiunta a Magazzino, Uscita da Magazzino, Import uscite da Excel, Tutti i Movimenti, Variazione Magazzino
  - **Magazzini e Ubiche**: Elenco Magazzini, Elenco Ubiche
- Bottom section: latest 10 `Itemin`, `Itemout`, and `Itemmovement` records.

### 2. Stock lookup — `inventories#index`

- Two execution paths depending on `params[:date]`:
  - **Current stock**: aggregates `StockLevel` rows by `gencode` (fast).
  - **Historical stock**: aggregates the `Inventory` event log, filtering records with `indate <= @date` (slower, accurate).
- Filters: warehouse, collection, text query, and a “show zero” toggle.
- Shows per-row history by `gencode` and `warehouse/location`, including the originating movement records.
- Each stock row has an **Export XLSX** action.

### 3. Export stock — `inventories/export_xlsx`

- Reuses the same query logic as `index` but returns an `.xlsx` via `caxlsx`.
- Includes date, warehouse, collection filters, and rows of code/collection/description/quantity.

### 4. Seleziona articoli — `inventories/seleziona`

- Lets the user pick multiple items from the catalog.
- Search and collection filter via the `search-filter` controller.
- Sidebar basket (controlled by `seleziona` controller) collects selected items and quantities.
- Submitting posts to `inventories/prepare_carico`, which stores the selection in `session[:carico_prefill]` and redirects to `app_in_warehouse_path` for mobile/carico entry.

### 5. QR select and print — `inventories/qr_select` and `inventories/qr_output`

- `qr_select`: browse items filtered by collection and `qr_printed` status, mark selected items as printed, and store their ids in the session.
- `qr_output`: renders a PDF of QR codes for the selected items using `wicked_pdf`.

### 6. Movimenti log — `inventories/movements`

- Combined timeline of `Itemin`, `Itemout`, and `Itemmovement` records.
- Filters: operation type, date range, operator, text query.
- Each row shows type, date, articles, quantity, warehouse/location, operator, and links to a PDF label or a modal detail view.
- Itemmovements show source → destination for both warehouse and location.

### 7. Movement label / modal — `inventories/movement_label` and `inventories/movement_modal`

- `movement_label(type, id)` generates a PDF label for the movement details.
- `movement_modal(type, id)` renders a modal with the full movement record and its details.

### 8. Itemin (warehouse inbound) — `itemins`

- `new`: build an `Itemin` with nested `itemins_details`.
- `create`: validates the form, stores the params in `session[:itemin_preview]`, and redirects to `preview`.
- `preview`: shows the details before confirmation.
- `confirm`: uses `MovementBuilder` to build the record, saves it in a transaction, and calls `CreateInventoriesFromItemin` to update `Inventory` and `StockLevel`.
- Each detail belongs to a warehouse, optional location, operation type, and item.
- When `Itemin` is saved, `Inventory` rows are created with `operationtype_id = 1` and `StockLevel.adjust_qty!` is called with positive quantity.

### 9. Itemout (warehouse outbound) — `itemouts`

- Same flow as `Itemin`: `new` → `create` → `preview` → `confirm`.
- `create` validates stock availability before accepting the preview.
- On confirm, `CreateInventoriesFromItemout` creates `Inventory` rows with `operationtype_id = 2` and decrements `StockLevel`.
- `itemouts/import`, `itemouts/import_parse`, `itemouts/import_confirm`, `itemouts/import_cancel`: bulk import outbound shipments from Excel using `ImportItemoutService`.

### 10. Itemmovement (warehouse transfer)

- No dedicated `ItemmovementsController`; creation is handled by:
  - `AppController#move_products` (mobile UI)
  - `API::V1::Inventories#transfer` (external clients/scanners)
  - `Archive::ItemsController` (archive checkout creates a movement)
- `CreateInventoriesFromItemmovement` writes two `Inventory` records per detail:
  - one `operationtype_id = 2` (out) from the source warehouse/location
  - one `operationtype_id = 1` (in) to the destination warehouse/location
- `StockLevel` is decremented at source and incremented at destination.
- `AppController#itemmovements_list` redirects to `inventories_movements_path(operationtype_id: 3)`.

### 11. Bulk import of movements — `inventories/import*`

- `import`: upload form; supports warehouse, location, and operation type overrides.
- `import_parse`: reads the Excel file with `ImportInventoryService` (Roo), auto-detects headers, validates each row against existing `Item`s, resolves warehouse/location/collection.
- `import`: preview/edit rows inline; `import_update_row` and `import_delete_row` modify the cached data.
- `import_verify`: intermediate confirmation screen.
- `import_confirm`: builds an `Itemin` or `Itemout` and runs the corresponding inventory creation service.
- `import_summary`: shows totals and errors.
- `import_cancel`: clears the cached import data.
- Operation type must be 1 (in) or 2 (out); transfers are not supported by this import.

### 12. QR lookup — `inventories/lookup_by_qr`

- Parses a scanned QR code with `QrParser`.
- If the QR encodes a `IteminsDetail` id, returns the original inbound warehouse/location plus the item’s last known position.
- Otherwise returns the legacy positions from `StockLevel.positive`.
- Used by the mobile QR scanner (`qr-scanner` controller) and the API `/api/v1/inventories/lookup`.

### 13. Autocomplete — `inventories/autocomplete`

- Returns JSON of items currently available in `Inventory` (operation type 1) with remaining quantity from `StockLevel`.
- Groups results by warehouse/location headers.
- Used by the mobile app and movement forms to pick items and validate stock.

### 14. Warehouse management — `warehouses`

- CRUD for warehouses.
- `qrcodes`: renders a PDF of warehouse/location QR codes.
- `lookup_by_qr`: returns JSON for a scanned warehouse or location gencode.
- `merge`: choose source warehouses and a target warehouse.
- `merge_apply`: runs `MergeWarehousesService` to move inventories, stock levels, and locations into the target and disable the source warehouses.

### 15. Location management — `locations`

- CRUD for locations (belongs to a warehouse).
- Redirects back to `warehouses_path` after create/update/destroy.
- Location QR codes are generated automatically on create/update.

## API endpoints (`/api/v1/inventories`)

- `GET /api/v1/inventories/lookup?q=…` — item + stock positions, plus inbound origin if QR includes detail id.
- `POST /api/v1/inventories/inbound` — create an `Itemin` and update stock.
- `POST /api/v1/inventories/outbound` — validate stock, create an `Itemout`, and update stock.
- `POST /api/v1/inventories/transfer` — validate stock, create `Itemmovement` records, update stock.
- `GET /api/v1/inventories/stock` — list positive `StockLevel` rows.

## General flow

1. **Stock entry**:
   - Desktop: `inventories/dashboard` → `new_itemin_path` → fill form → preview → confirm → `CreateInventoriesFromItemin` updates stock.
   - Mobile: `app_in_warehouse` → scan/type items → confirm → posts via `IteminsController` or API.
   - Bulk: `inventories/import` → upload Excel → preview → confirm → `ImportInventoryService`.

2. **Stock exit**:
   - Desktop: `inventories/dashboard` → `new_itemout_path` → fill form → stock validation → preview → confirm → `CreateInventoriesFromItemout`.
   - Mobile: `app_out_warehouse` → scan/type items → confirm.
   - Bulk: `import_itemouts_path` → upload Excel → confirm → `ImportItemoutService`.

3. **Transfer**:
   - Mobile: `app_move_products` → source/destination warehouse/location → scan items → confirm → grouped `Itemmovement` records → `CreateInventoriesFromItemmovement`.
   - API: `POST /api/v1/inventories/transfer`.

4. **Query**:
   - `inventories/index` for current stock, historical stock, or export.
   - `inventories/movements` for the movement log.
   - `inventories/lookup_by_qr` or the mobile scanner to locate an item.

## Operational gotchas

- `Itemmovement` has **no dedicated Rails controller** despite being a core model. Creation is split between `AppController`, `API::V1::Inventories`, and `Archive::ItemsController`.
- The import pipeline only supports inbound/outbound operations; transfers must be done through the mobile or API flow.
- Current stock is read from `StockLevel`; historical stock is computed from `Inventory` rows.
- QR codes encode detail ids for inbound records, so scanning a QR can pre-fill the inbound warehouse/location.
