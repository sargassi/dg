# Current Feature

Inventories Excel import (Magazzino → Import): materialize missing items from a parsed sheet and show a richer import preview.

## Status

Implemented (uncommitted on `main`).

## Goals

- Keep the strict import validation (rows referencing `Item`s that don't exist stay red / are skipped), but let the operator create those missing `Item` records straight from the uploaded sheet.
- Make the "Anteprima importazione" page show at-a-glance import health instead of only the raw table.

## Summary

- `ImportInventoryService#create_missing_items(data)` dedupes invalid rows by `[itemcode, fabricode, varcode]`, resolves the collection from the `Note:` column via the existing `find_or_create_collection`, creates each distinct `Item` (with `description`/`tg`/`fabric`/`colour`/`materiale` filled from their columns), then re-runs `validate_row` on every row so `_valid`/`_item_id` are refreshed in place. Rows with a blank Item code ("Item code mancante") are not creatable and stay invalid. Returns `{ created:, failed: }`.
- `InventoryImportController#import_create_missing_items` (POST) reads the cached parse, calls the service, rewrites the cache, and redirects back to the preview with a notice.
- Route `POST inventories/import/create_missing_items`.
- `app/views/inventories/import.html.erb` now shows: a stat strip (Totali / Valide / Non valide / Nuovi WH / Nuove coll.), an aggregated error panel grouped by error with a distinct missing-codes count, and a "Crea N articoli mancanti" button (only when creatable invalid rows exist).

## Files changed

- `app/services/import_inventory_service.rb` (+`create_missing_items`)
- `app/controllers/inventory_import_controller.rb` (+`import_create_missing_items`)
- `config/routes.rb`
- `app/views/inventories/import.html.erb`
- `test/services/import_inventory_service_test.rb` (+2 tests), `test/controllers/inventory_import_controller_test.rb` (+3 tests, stubbed `import_cache_key` to a fixed key and swapped `Rails.cache` to a `MemoryStore` because test env uses `:null_store`)

## Notes

- Red rows for unknown item codes are intentional (commit `db65be2`) — the validation was not changed.
- Test env uses `:null_store`, so the controller tests override `Rails.cache` and stub the private `import_cache_key` to a constant to make the parse → create flow deterministic (the integration client regenerates the session id between requests).
- `Item#before_save` rebuilds `gencode` and regenerates the QR SVG automatically; created items therefore get QR labels.
- `create_missing_items` temporarily skips the `regenerate_qr` callback during the bulk creation (`Item.skip_callback` / `ensure` re-add): generating an SVG per item (~21ms each) made ABITI-scale creation take ~50s with no feedback. New items get `qrcode_svg: nil`, which is safe — every view guards with `.present?`/`&.html_safe`, and printed labels build the QR on demand via `CreateQrService`. Measured: 600 items 15.1s → 2.4s.
- The "Crea articoli mancanti" button now sits inside a `loader` Stimulus controller with a spinner overlay (`turbo_submits_with` + `submit->loader#show`), so the request no longer looks stuck.
- Known remaining slowness: `Roo::Excelx` parsing of the 65 MB `assets/ABITI.xlsx` takes minutes (pre-existing; the upload form already shows a "Caricamento in corso..." spinner).
