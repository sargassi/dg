# Seleziona Articoli (Magazzino) — Flow & Instructions

## Purpose

The **Seleziona Articoli** screen (`inventories/seleziona`) lets an operator pick multiple catalog
`Item`s and hand them off to the mobile **Carico** (inbound) flow. It is a *selection* screen only:
it does not touch stock. Stock changes happen later in `AppController#in_warehouse`.

Selection state lives entirely in the browser (a Stimulus controller in-memory array), not in the
session. Only when the operator submits does `prepare_carico` write `session[:carico_prefill]`.

## How the user experiences it

1. Land on `GET inventories/seleziona` (from the Inventories dashboard card **Seleziona Articoli**).
2. Search across all columns (debounced, server-side) and/or filter by collection. Results render
   inside a `turbo-frame` named `items-table`, so typing does not reload the page.
3. Tick checkboxes on rows. Each checked row turns green. A **basket sidebar** appears on the right
   listing the selected gencode + collection with a qty input per row.
4. Adjust quantities, remove rows from the basket (which unchecks the row), or keep browsing pages —
   selections survive Turbo frame reloads via `syncFrame`.
5. Press **Vai a Carico →** → POST to `inventories/seleziona/prepare_carico` → redirect to the
   mobile Carico screen (`app_in_warehouse`) pre-filled with the selection.

## Files involved

| File | Role |
|---|---|
| `app/views/inventories/seleziona.html.erb` | The screen: search bar, results table frame, pagination, basket sidebar |
| `app/views/inventories/_seleziona_item_row.html.erb` | One table row: checkbox + image + item columns |
| `app/javascript/controllers/seleziona_controller.js` | Basket logic: selection array, qty, hidden inputs, frame re-sync |
| `app/javascript/controllers/search_filter_controller.js` | Debounced server search (`filter`), result highlight, count badge |
| `app/controllers/inventory_stock_controller.rb` | `seleziona` (GET) and `prepare_carico` (POST) |
| `app/controllers/app_controller.rb` | `in_warehouse` consumes `session[:carico_prefill]` |
| `config/routes.rb` | `inventories_seleziona` / `inventories_prepare_carico` |
| `app/helpers/inventories_helper.rb` | Dashboard card link (`manage_inventory`) |

## Routes

```ruby
get  'inventories/seleziona',                  to: 'inventory_stock#seleziona',     as: :inventories_seleziona
post 'inventories/seleziona/prepare_carico',   to: 'inventory_stock#prepare_carico', as: :inventories_prepare_carico
```

Both guarded by `require_ability!('manage_inventory')` (except `lookup_by_qr`/`autocomplete`).

## Controller behavior

### `InventoryStockController#seleziona`

- Loads `@collections` (collections that have items, ordered by `row_order DESC`).
- Loads `@itemz = Item.includes(:collection).with_attached_pictures` (single query, avoids N+1 on
  the image column).
- Optional filters:
  - `params[:collection_id]` → `where(collection_id:)`
  - `params[:q]` → LIKE across `gencode, itemcode, fabricode, varcode, description, fabric, colour`.
- Paginates with Pagy. **No `items` param** — defaults to the Pagy default page size.

### `InventoryStockController#prepare_carico`

- Reads `params[:selected]` (array of hashes built by JS: `item_id, gencode, collection_id, qty`).
- Stores a permitted slice in `session[:carico_prefill]`.
- Redirects to `app_in_warehouse_path(return_to: inventories_seleziona_path)` with a notice.

## View anatomy (`seleziona.html.erb`)

- Root `<section>` wires **two** Stimulus controllers: `seleziona` (basket) and `search-filter`
  (debounce/filter). Fixed-height layout: `height: calc(100vh - 110px)`.
- **Search bar** (`form_with ... method: :get`, `turbo_frame: "items-table"`): text input + collection
  select + a live count badge (`data-search-filter-target="count"`). `search-filter#filter` debounces
  (150ms) then `form.requestSubmit()`.
- **`turbo_frame_tag "items-table"`**: contains the `<table>` body rendered via
  `render partial: 'seleziona_item_row', collection: @itemz`. On `turbo:frame-load` it calls
  `search-filter#onFrameLoad` (re-highlight + refresh count + refocus) and `seleziona#syncFrame`
  (re-check still-visible selected rows and re-render basket).
- **Loading UX**: `<style>` rules hide `.items-table-content` and show a spinner while the frame is
  `busy`.
- **Pagination**: prev/next + `@pagy.series` links, all with `data-turbo-frame="items-table"`.
- **Basket sidebar** (`data-seleziona-target="basket"`), initially `hidden`:
  - header: count text (`basketCount`)
  - scrollable list (`basketItems`) rendered client-side by JS
  - footer: `form_tag inventories_prepare_carico_path, method: :post` with a hidden-inputs container
    (`hiddenInputs`) and the **Vai a Carico →** submit button.

## Stimulus behavior (`seleziona_controller.js`)

- `connect()` resets `this.selected = []`.
- `toggleItem(event)` on checkbox `change`: pushes/removes a row descriptor
  (`id, gencode, collectionId, collection, itemcode, qty:1`) and toggles the `bg-green-200` row class.
- `removeItem(event)`: removes from array, unchecks the matching checkbox (if present in DOM), removes
  highlight, re-renders basket.
- `updateQty(event)`: mutates `qty` in place, re-renders hidden inputs.
- `renderBasket()`: hides the sidebar when empty, else updates count + innerHTML (escaped via
  `escape()`) and calls `renderHiddenInputs()`.
- `renderHiddenInputs()`: emits `selected[][item_id|gencode|collection_id|qty]` hidden inputs into the
  footer form — this is what `prepare_carico` receives.
- `syncFrame()` (on `turbo:frame-load`): re-checks rows that are in `this.selected` and re-renders the
  basket. **This is what keeps selections alive across pagination/search results.**

## Handoff to Carico (`AppController#in_warehouse`, GET branch)

- If `session[:carico_prefill]` present: deletes it from session, maps each entry to an
  `itemins_detail` (`itemcode` from the `Item`, `item_id`, `collection_id`, `qty`, `operationtype_id: 1`)
  and pre-builds them on `@itemin`. Also sets `@default_collection_id` from the first detail and
  `@from_seleziona = true` (used to render a "back to selection" affordance).
- `@from_seleziona` is also derived from `return_to` containing `inventories_seleziona_path`, so the
  state survives the first (empty) load.

## Gotchas & edge cases

- **Selection is ephemeral**: refresh the page → selections lost. Only persisted at submit time via
  the session, and consumed (deleted) by the first `in_warehouse` GET.
- **qty parse**: `parseInt(...) || 1` — non-numeric/zero becomes 1; no upper bound enforced.
- **XSS**: basket innerHTML is escaped via `escape()`, but `syncFrame`/`toggleItem` data attributes
  come from server-rendered DB values — keep the row partial's attributes ERB-escaped (Rails does by
  default).
- **No stock awareness**: any catalog item can be selected regardless of current stock; the mobile
  Carico form is responsible for the actual quantities/warehouses.
- **Collection dropdown** and **search** are independent: selecting a collection does not reset `q`,
  and vice versa — both params combine server-side.
- `with_attached_pictures` on the full catalog can be slow on large datasets; pagination keeps the
  rendered rows bounded, but the image lookup is eager-loaded up front.
- Pagination links rebuild via `pagy_url_for(@pagy, ...)`, so they carry the current `q` and
  `collection_id` filters automatically.

## Tests

Coverage lives in `test/controllers/inventory_stock_controller_test.rb`:

- `seleziona` renders a checkbox row per catalog item and the live count badge.
- `seleziona` honors `collection_id` and `q` (text) filters independently.
- `prepare_carico` stores the permitted selection slice in `session[:carico_prefill]` and redirects
  to `app_in_warehouse_path(return_to: inventories_seleziona_path)`.

Run: `bin/rails test test/controllers/inventory_stock_controller_test.rb`.

## Resume checklist (when continuing work on this screen)

1. **Verify current behavior** — `bin/rails test test/controllers/inventory_stock_controller_test.rb`
   and manually in the browser: `bin/dev` → Magazzino → Seleziona Articoli.
2. Confirm search (debounce + highlight + count), collection filter, pagination with selection
   persistence, basket qty/remove, and the Carico handoff all still work.
3. If adding features, document them here and in `context/current-feature.md` first (per
   `context/ai-interactions.md`).
4. Not yet covered: pagination behavior on a catalog larger than the Pagy page size, and the
   end-to-end pick → Vai a Carico → Carico pre-fill (request/system test).

## Ideas already in the air (confirm before building)

- Persist the basket in `session`/localStorage so an accidental reload does not lose the selection.
- Show per-row current stock (from `StockLevel`) in the table or basket.
- Cap or warn on large quantities.
- Allow editing the collection from within the basket rows.