# Archive — Import from Main Warehouse

## Overview

Allow warehouse items to be moved out of the main warehouse (scarico) and simultaneously
(or independently) become archive items, linked back to the originating Inventory record.

## Data Model

### `Archive::Item` — add `inventory_id`

```ruby
# Migration: AddInventoryIdToArchiveItems
add_reference :archive_items, :inventory, foreign_key: true, null: true
```

- `inventory_id` (nullable FK → `inventories.id`)
- Each archive item optionally references the specific Inventory record created when the
  mainware item was checked out (scarico). This is the link between the two systems.
- An archive item can exist without an `inventory_id` (normal manual creation).
- When created via import from warehouse, the `inventory_id` is set to the Inventory
  record with `operationtype_id = 2` (itemout) that records the outflow.

### Model changes

```ruby
# app/models/archive/item.rb
belongs_to :inventory, optional: true  # link to mainware Inventory record
```

No changes to mainware models (Item, Inventory, Itemout, StockLevel).

## Entry Points

### 1. Right sidebar autocomplete (`/archive/items/index`)

A collapsible panel at the bottom of the right sidebar ("Importa da magazzino").
Contains:

- **Code search** — text input + autocomplete (reuses existing `autocomplete` Stimulus
  controller). Backend: new action `Archive::ItemsController#warehouse_search` that
  queries `Inventory` + `Item` + `StockLevel` to return items with available stock
  and their warehouse/location positions.
- **QR scan** — button that opens the existing `qr-scanner` overlay. On scan, resolves
  the QR code and shows the item with its positions.
- On selection of an item + position: two inline buttons:
  - **"Scarica"** → Redirects to the standard Itemout new form
    (`/inventories/itemouts/new`) with the item pre-filled as a detail row, using
    `session[:archive_itemout_prefill]`.
  - **"Crea in archivio"** → Opens the new-archive-item form pre-filled with:
    - `name` ← Item description or item code
    - `notes` ← Item note
    - pictures copied from Item
    - `inventory_id` ← the selected Inventory/StockLevel record (or the one created
      by the scarico)
    - User fills in: category, archive location, adjusts name, etc.

If "Scarica" was done first, "Crea in archivio" automatically picks up the Inventory
record that was just created.

### 2. Batch import page (`/archive/import`)

New page at `GET /archive/import`, modeled after `inventories/seleziona`.

**Layout:**
- Left (flex-1): search/filter bar + paginated table of mainware items with stock
  positions. Columns: checkbox, gencode, itemcode, description, warehouse, location,
  qty_available.
- Right (w-80 sidebar): basket with selected items, each with qty input.

**Controller:** `Archive::ItemsController#import` action.

**Data source:** Joins `items` + `stock_levels` + `warehouses` + `locations`.
Only shows items with `current_qty > 0`.

**Basket actions:**
- **"Scarica da magazzino"** → Sends selected items to `ItemoutsController#create`
  (via a dedicated `Archive::ItemsController#create_itemout` action that stores
  selections in `session[:archive_itemout_prefill]` and redirects to the Itemout
  preview). Follows the standard preview → confirm flow.
- **"Importa in archivio"** → Opens a modal/batch form where the user picks archive
  category and location for each item (or a default for all), then confirms.
  Creates Archive::Item records with data copied from the mainware Item and
  `inventory_id` set.

## Two Flows (Separated but Linked)

### Flow 1: Scarico (Itemout)

Follows the existing pattern:
1. User selects items + warehouse/location + qty
2. System creates `Itemout` + `ItemoutsDetails`
3. `CreateInventoriesFromItemout` creates `Inventory` records (`operationtype_id = 2`)
   and decrements `StockLevel`
4. User is redirected back to the archive import page (or archive items index)

### Flow 2: Archive Item Creation

1. User selects mainware items (must have an existing Inventory record, or one is
   created first via Flow 1)
2. User fills archive-specific fields (category, archive location, custom name, etc.)
3. System creates `Archive::Item` with:
   - `name` ← copied from Item (editable)
   - `notes` ← copied from Item
   - Pictures duplicated from Item via blob copy
   - `inventory_id` ← the Inventory record from Flow 1
   - `status` ← "in" (the archive item starts "in archivio")
4. Redirect to archive items index with success notice

## User Stories

### US1: Quick single-item lookup + import
1. User is on `/archive/items`, opens "Importa da magazzino" in the sidebar
2. Types a code or scans a QR
3. Autocomplete shows matching items with available positions
4. User selects an item + position
5. Clicks "Scarica" → itemout created, confirmation shown
6. Then clicks "Crea in archivio" → form pre-filled with item data +
   `inventory_id` already set, user adds category/location and saves

### US2: Batch selection + combined flow
1. User navigates to `/archive/import`
2. Searches/filters mainware items with stock > 0
3. Checks items, basket shows selected with qty per position
4. Clicks "Scarica selezionati" → goes through itemout preview → confirm
5. Redirected back to archive import with items marked as "scarico complete"
6. Clicks "Importa in archivio" → batch form with default category/location
7. Confirms → Archive::Items created, linked to Inventory records

### US3: Import without scarico (already-out items)
1. User finds an item that was previously checked out (already has an Inventory
   record with operationtype_id = 2)
2. Selects it in the autocomplete or import page
3. "Crea in archivio" is available directly (scarico already done)
4. Archive item is created linked to the existing Inventory record

## URLs / Routes

```ruby
namespace :archive do
  resources :items do
    collection do
      get :warehouse_search  # JSON autocomplete for mainware items
      get :import             # batch selection page
      post :import_itemout    # create itemout for selected items
      post :import_confirm    # create archive items from selected
    end
  end
end
```

`/archive/items/warehouse_search` — JSON endpoint, returns items with stock positions
`/archive/items/import` — batch selection page
`/archive/items/import_itemout` — POST, creates Itemout from selected items
`/archive/items/import_confirm` — POST, creates Archive::Items

## Implementation Plan

### Phase 1: Data model
- Migration: add `inventory_id` to `archive_items`
- Update `Archive::Item` model with `belongs_to :inventory, optional: true`

### Phase 2: Warehouse search endpoint
- `Archive::ItemsController#warehouse_search` — queries items + stock_levels
- Returns JSON with item data and positions for autocomplete

### Phase 3: Right sidebar autocomplete
- Update `app/views/archive/items/index.html.erb` — add "Importa da magazzino"
  collapsible panel in the sidebar
- Wire up autocomplete controller + QR scan
- "Scarica" and "Crea in archivio" inline buttons

### Phase 4: Batch import page
- `app/views/archive/items/import.html.erb` — selection table + basket
- `Archive::ItemsController#import` action
- `import_itemout` and `import_confirm` actions

### Phase 5: Integration
- Itemout creation (direct save or via existing preview/confirm)
- Archive::Item creation with data copy and inventory_id link
- Picture duplication from Item to Archive::Item
