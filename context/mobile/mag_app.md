# Mobile IN / OUT / VAR wizard — "Mag App"

Mobile-optimized warehouse movement flows for the App section (`AppController`).

## Goal

Add 3 new mobile actions — `mobile_in`, `mobile_out`, `mobile_var` — that follow the **same business flow** as the existing `in_warehouse` / `out_warehouse` / `move_products` but are redesigned as a **step-by-step wizard** for on-the-floor operators. The existing views/partials for the desktop flows must NOT be touched.

## Decisions (confirmed with user)

- **UX**: step-by-step wizard, single page, client-side step switching (new Stimulus controller).
- **Action names/routes**: `mobile_in` / `mobile_out` / `mobile_var` (+ `mobile_*_confirmation`).
- **Wizard state**: single page, client-side steps (no server round-trips between steps).
- **Item entry**: scan-and-add cart (one scan/type input, running list, inline qty).
- **Cart → server**: hidden nested-form rows appended by JS → standard `*_details_attributes` params → reuses `MovementBuilder` / `MovementCreationService` / `InventoryCreator`. Backend flow identical to existing flows.
- **Endpoints**: reuse existing `autocomplete_items_path` / `autocomplete_inventories_path`, `inventories/lookup_by_qr`, `warehouses/lookup_by_qr`.
- **Steps**: IN/OUT = 2 steps (Dove → Articoli+Salva). VAR = 3 steps (Da → A → Articoli+Salva). Date/notes/operator hidden & pre-filled.
- **Links re-pointed**: only `app_section_toolbar` IN/OUT/VAR (app dashboard Magazzino card links to list pages, inventory dashboard keeps desktop flows).
- **Post-save**: new mobile confirmation screens.

## Files

### New routes — `config/routes.rb`

```ruby
match 'app/mobile_in',  to: 'app#mobile_in',  via: [:get, :post], as: :app_mobile_in
match 'app/mobile_out', to: 'app#mobile_out', via: [:get, :post], as: :app_mobile_out
match 'app/mobile_var', to: 'app#mobile_var', via: [:get, :post], as: :app_mobile_var
get 'app/mobile_in_confirmation',  to: 'app#mobile_in_confirmation',  as: :app_mobile_in_confirmation
get 'app/mobile_out_confirmation', to: 'app#mobile_out_confirmation', as: :app_mobile_out_confirmation
get 'app/mobile_var_confirmation', to: 'app#mobile_var_confirmation', as: :app_mobile_var_confirmation
```

### `app/controllers/app_controller.rb`

- `mobile_in` / `mobile_out`: GET → empty movement (`Itemin`/`Itemout`, `indate: Date.current`) + `load_form_data`. POST → `MovementCreationService.new(<Class>, params, defaults: { warehouse_id:, location_id: })` then redirect to confirmation (or re-render on error).
- `mobile_var`: GET → `Itemmovement.new(indate: Date.current)` + `load_form_data(ordered: true)`. POST → same grouping/stock-check logic as existing `move_products` (Da per-row warehouse/location, single A from `dest_warehouse_id`/`dest_location_id`), then redirect to confirmation (or re-render on error).
- `mobile_in_confirmation` / `mobile_out_confirmation` / `mobile_var_confirmation`: load the saved movement(s) (`includes` of details + warehouse/location/item), render mobile confirmation view.
- Reuses `set_app_menu`, `load_form_data`, `set_return_to`. Ability gate (`manage_app_sectors`) already applies to all actions except `sez`/`check_single_qr`.

### Layout & toolbar

- `app/views/layouts/application.html.erb` — add the 6 new actions to the chrome list (app side menu + header shows on wizard/confirmation pages).
- `app/helpers/application_helper.rb` `section_toolbar_items` — route the mobile actions to `app_section_toolbar`.
- `app/helpers/app_helper.rb` `app_section_toolbar` — IN → `app_mobile_in_path`, OUT → `app_mobile_out_path`, VAR → `app_mobile_var_path`.

### New Stimulus controller — `app/javascript/controllers/mobile_wizard_controller.js`

- Step navigation: `data-mobile-wizard-target="step"` sections, next/back buttons, progress indicator (VAR 3 steps).
- Scan-and-add cart: scan input (uses `autocomplete` + `qr_scanner`); on resolved item append a visible cart row (code, description, qty stepper, remove) + a hidden nested-form row cloned from a `<template>` with a unique `child_index`, filling `item_id`/`gencode`/`warehouse_id`/`location_id`/`operationtype_id`/`qty`.
- Duplicate scan increments qty. Auto-advance focus after each scan.
- `operationtype_id`: IN=1, OUT=2, VAR=3.
- On submit, hidden rows serialize as standard nested attributes.

### New views

- `app/views/app/mobile_in.html.erb` — Step 1 "Dove" (warehouse/location selects + QR via existing `defaults` controller + `scanWarehouseLoc`), Step 2 "Articoli" cart + sticky Salva.
- `app/views/app/mobile_out.html.erb` — same 2-step structure (source location).
- `app/views/app/mobile_var.html.erb` — Step 1 "Da", Step 2 "A", Step 3 "Articoli" + Salva.
- `app/views/app/mobile_in_confirmation.html.erb` / `mobile_out_confirmation.html.erb` / `mobile_var_confirmation.html.erb` — compact summaries (success banner, item list, "Nuovo" + "Dashboard" buttons).
- All mobile-first: full-width, large touch targets, sticky bottom save bar.

### Tests — `test/controllers/app_controller_test.rb`

- GET each mobile action → success.
- POST each with a valid detail row → count increments + redirect to confirmation.
- POST error path (no details / bad stock) → re-renders wizard with alert.

## Not touched

- `app/views/app/_in_warehouse_fields.html.erb`
- `app/views/app/out_warehouse.html.erb`
- `app/views/app/move_products.html.erb`
- `app/views/app/in_warehouse.html.erb`
- inventory dashboard links (`inventories/dashboard.html.erb`)

## Verification

- `bin/rails test test/controllers/app_controller_test.rb`
- Manual narrow-viewport check of `/app/mobile_in`, `/app/mobile_out`, `/app/mobile_var`.
