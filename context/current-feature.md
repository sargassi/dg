# Current Feature

App "RIALLOCA" action — reassign imported inventory to the correct warehouse/location without creating movements.

## Status

Implemented (uncommitted on `main`).

## Goals

- Let operators correct stock placed in the wrong warehouse/location after an Excel import.
- Must NOT create an `Itemmovement` / `Itemin` / `Itemout` and must NOT use an `operationtype`; it directly rewrites `StockLevel` and `Inventory` rows.
- Mobile-wizard UX matching IN/OUT/VAR/QR flows: optional scan/autocomplete, place-filtered autocomplete, session-free confirm.

## Summary

- `ReassignStockService` moves, per selected `gencode`, only the positive `StockLevel` rows that match the source place (warehouse required; location optional — blank moves all rows in the warehouse). Quantity is added to the destination via `StockLevel.adjust_qty!` (merging into an existing destination row), subtracted from the source, and emptied source rows are destroyed. Matching `Inventory` rows have `warehouse_id`/`location_id` rewritten to the destination.
- `AppController#mobile_reassign` (GET renders the 3-step wizard, POST validates source/destination/articles then calls the service) and `AppController#mobile_reassign_confirm` (shows per-gencode stats, reads `session[:mobile_reassign_result]`).
- New routes `app/mobile_reassign` (GET/POST) and `app/mobile_reassign_confirm`.
- New views `app/views/app/mobile_reassign.html.erb` and `app/views/app/mobile_reassign_confirm.html.erb`, reusing `_mobile_location_step`, the autocomplete + `defaults` (`da`/`a` prefixes), and the QR scan overlays.
- Menu entry "RIALLOCA" in `set_app_menu`, gated by `manage_app_sectors` (same as the other App actions).

## Files changed

- `app/services/reassign_stock_service.rb` (new)
- `app/controllers/app_controller.rb` (`mobile_reassign`, `mobile_reassign_confirm`, menu entry)
- `config/routes.rb`
- `app/views/app/mobile_reassign.html.erb`, `app/views/app/mobile_reassign_confirm.html.erb` (new)
- `test/controllers/app_controller_test.rb` (+7 tests), `test/services/reassign_stock_service_test.rb` (new, +7 tests)

## Notes

- The `.well-known/appspecific` routing-noise fix was explicitly dropped by the user — do not implement.
- `StockLevel#adjust_qty!` normalizes `location_id || 0`; the service keys on that convention and merges destination rows.
- `delete!` is unavailable on ActiveRecord 7.2.3.2 records; the service uses `destroy!` for emptied source rows.
