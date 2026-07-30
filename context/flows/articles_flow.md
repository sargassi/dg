# Mainware Flow

## Module purpose

Mainware is the legacy/general warehouse module. It is centered on the `Item` catalog (articles/products), collections, prices, bulk Excel imports, and QR-based lookup. Everything under `mainware/` requires the `manage_mainware` ability.

## Entry points

- `mainware/dashboard` (also `mainware/home`) — landing page with cards for:
  - Inserimento (`new_item_path`)
  - Importa (`mainware_import_path`)
  - Ricerca Articoli (`mainware_index_path`)

## Subsections

### 1. Articoli — `mainware/index`

- Paginated list of `Item` records.
- Search across `gencode`, `itemcode`, `fabricode`, `varcode`, `description`, `fabric`, `colour`.
- Collection dropdown filter.
- Each row shows item codes, description, size, fabric, colour, material, note, collection, prices, QR SVG, attached photos, and edit/delete actions.
- Sibling rows: items with the same `itemcode + fabricode + varcode` are grouped. The first row shows a “Storico” button that expands sibling rows from other collections to compare prices.
- Live search via the `search-filter` Stimulus controller inside the `items-table` Turbo Frame.
- Header button opens the Excel import flow.

### 2. Nuovo articolo — `items#new`

- Not handled by `MainwareController`; the dashboard links to the standard `ItemsController#new`.
- Mainware is mostly a read/search/browse wrapper around `Item`.

### 3. Ricerca QR — `mainware/searchqr`

- Same search logic as `mainware/index`, but with a QR scanner interface.
- Uses the `qr-scanner` Stimulus controller and the ZXing library (`@zxing/library`) to read QR codes from the camera.
- After scanning, the decoded value is placed in the search field and the form is submitted.
- Results render using the same `_item_row` partial.

### 4. Storico Prezzi — `mainware/prices_compare`

- Groups items by `[itemcode, fabricode, varcode]`.
- Lists all sibling `Item` records ordered by collection creation date.
- Used to compare unit prices across collections.
- Has its own live search inside the `price-table` Turbo Frame.

### 5. Import da Excel — `mainware/import*`

Multi-step bulk import pipeline.

#### Upload / parse — `mainware/import` + `mainware/import_parse`

1. User uploads an `.xlsx` file and optionally selects a collection override.
2. `ImportGeneralService` uses `Roo` to read the spreadsheet.
3. The header row is auto-discovered by looking for known headers (`Item Code:`, `Fabric code:`, `var. code:`, `Description:`, `Prezzo showroom`, `materiale`, `colour:`, `Tg.`).
4. Columns are mapped to `Item` fields.
5. Collection is resolved from the `Note:` column or the override; a new collection is created if needed.
6. Warehouse is resolved from the `dove` column; a new warehouse is created if needed.
7. A `_gencode` is computed for each row.
8. Parsed data is stored in Rails cache keyed by the session id.

#### Preview / edit — `mainware/import`

- Shows the parsed rows in an editable table.
- Inline editing via the `inline-edit` Stimulus controller:
  - Changes are sent immediately to `mainware/import_update_row` via `PUT`.
  - If item/fabric/var codes change, the gencode is recalculated.
- Rows can be deleted via `mainware/import_delete_row` (Turbo Stream).
- Summary box shows which warehouses and collections will be used and which are new.

#### Confirm — `mainware/import_confirm`

- Writes a progress entry to cache and enqueues `ImportJob.perform_later(session_id)`.
- Redirects to the processing page.

#### Processing — `mainware/import_processing`

- Shows a progress bar and spinner.
- Polls `mainware/import_progress_json` via the `import-progress` Stimulus controller.

#### Job execution — `ImportJob`

- Reads the cached parsed data.
- Calls `ImportGeneralService#save` for each row, yielding progress updates.
- Creates or updates `Item` records and generates QR SVGs.
- Writes final stats to cache.

#### Summary — `mainware/import_summary`

- Displays total rows, created, updated, and errors.
- Lists per-row error details.
- Provides a link back to the item list.

#### Rollback — `mainware/import_rollback`

- Destroys only the records whose IDs were recorded as created during import.
- Updates are **not** rolled back.

#### Cancel — `mainware/import_cancel`

- Deletes the cached parsed data before confirmation.

### 6. Search placeholder — `mainware/search`

- Currently a stub view.

### 7. Stage — `mainware/stage`

- Empty action and view.

## Data relationships

- `Item` belongs to `Collection`.
- `Item#gencode` = `itemcode + fabricode + varcode + "_" + collection_id`.
- `StockLevel` tracks available quantity by `gencode + warehouse + location`.
- `Inventory` records every stock movement and links to `Itemin`, `Itemout`, or `Itemmovement`.
- `Itemout` is an outbound shipment with nested details.

## Operational gotcha

`ImportJob` exists and is enqueued during import confirmation, but the project has **no Active Job queue adapter configured**. In development and test it runs inline, which is fine for small imports. In production it would require a queue adapter or inline execution to be added.
