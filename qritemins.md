# QR Code Strategy for Inventory Tracking (Itemins)

## Problem

Currently the QR encodes only `gencode` (item identity). When an operator scans it, they learn *what* the item is but not *where* it is. If a movement between warehouses isn't registered immediately, there's no way to trace the last known position from the QR.

## Goal

Each physical label QR must be unique per inventory entry and link to the original inbound event, so the last known warehouse/location can be traced through movement history.

## QR Data Format

```
<itemcode><fabricode><varcode>_<collection_id>_<itemins_detail_id>
```

Which equals:

```
gencode + "_" + itemins_detail_id
```

Since `itemins_detail_id` is always an integer and `gencode` contains exactly one `_` (before `collection_id`), the last `_<digits>` segment is the detail ID and everything before is the `gencode`. Parsing is unambiguous.

## Current State (no changes needed to)

- **Item model `before_save :regenerate_qr`** — generates SVG from `gencode` for web display. Leave as-is.
- **QR SVG on Item** (`qrcode_svg` column) — used in web views. Leave as-is.
- **Warehouse/Location QR** — separate concern, leave as-is.

## What Changes

### 1. QR Generation in Physical Label Flow

Where physical labels are printed (PDF), change the QR text from `gencode` to `"#{gencode}_#{itemins_detail_id}"`. This is in `CreateQrService` or wherever the label PDF calls it.

### 2. Store QR on Inventory Record

Add a `qrcode_svg` text column to `inventories` table. At goods receipt time (`CreateInventoriesFromItemin`), generate the SVG from the new combined string and cache it on the Inventory record. This avoids regenerating it every time a label is printed.

### 3. Scanning Endpoint

When a QR is scanned:

1. Parse the scanned text:
   - If it contains `_` before a trailing integer → extract `itemins_detail_id` and `gencode`
   - If no match (legacy QR) → treat entire string as `gencode` (fallback)
2. Look up `Item` by `gencode`
3. Look up `IteminsDetail` by `detail_id` → get origin `warehouse_id` / `location_id`
4. Find the most recent `Inventory` record for this item to get the **last known position** (scan `Inventory` by `item_id`, `warehouse_id`, `location_id`, ordered by `created_at` desc)
5. Return the item info + last known warehouse/location + movement chain

### Backward Compatibility

- **Existing QR labels** (plain `gencode`, no trailing `_<id>`) — fall back to current lookup by `gencode`
- **Existing items** with `qrcode_svg` — untouched
- Only new goods receipts after this change generate the new format

### Files to Touch

| File | Change |
|------|--------|
| `app/services/create_inventories_from_itemin.rb` | Generate QR SVG with combined string, store on Inventory record |
| `db/migrate/*_add_qrcode_svg_to_inventories.rb` | New migration: add `qrcode_svg` (text) to `inventories` |
| `app/services/create_qr_service.rb` | Accept combined string when called for physical label PDFs |
| Label PDF views | Pass `gencode + "_" + detail_id` instead of just `gencode` |
| Scan/lookup controller | Parse new format, trace movement history |

### Non-Goals

- Changing the Item model's QR auto-generation
- Changing Warehouse/Location QR
- Breaking existing QR labels
- Collection ID tracking (already in `gencode`)
