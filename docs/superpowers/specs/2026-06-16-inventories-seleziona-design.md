# Seleziona Articoli per Carico — Design

## Overview

Add a `seleziona` action under `InventoriesController` that lets users search/browse items across all collections, select them via checkboxes, and push them into a fixed basket bar. From the basket, users proceed to the existing `app/in_warehouse` form with items pre-filled as rows.

## Route & Controller

```
GET /inventories/seleziona  →  InventoriesController#seleziona
```

- `before_action -> { require_ability!('manage_inventory') }` (same as existing inventories actions)
- Same pagination/search pattern as `MainwareController#index` but showing **all items across all collections** (no default collection filter)

**Controller logic:**
```ruby
def seleziona
  @collections = Collection.joins(:items).distinct.order(row_order: :desc)
  @itemz = Item.includes(:collection)

  if params[:collection_id].present?
    @itemz = @itemz.where(collection_id: params[:collection_id])
  end

  if params[:q].present?
    q = "%#{params[:q]}%"
    @itemz = @itemz.where(
      "gencode LIKE :q OR itemcode LIKE :q OR fabricode LIKE :q OR varcode LIKE :q OR description LIKE :q OR fabric LIKE :q OR colour LIKE :q",
      q: q
    )
  end

  @pagy, @itemz = pagy(@itemz)
end
```

## View — `app/views/inventories/seleziona.html.erb`

### Header

Same menu as `inventories/dashboard.html.erb`:
```erb
<% menu = [
  { label: 'Dashboard', path: inventories_dashboard_path, active: false, icon: 'dashboard', can: 'manage_inventory' },
  { label: 'Ricerca magazzino', path: inventories_path, active: false, icon: 'inventory_2', can: 'manage_inventory' },
  { label: 'Movimenti', path: inventories_movements_path, active: false, icon: 'swap_vert', can: 'manage_itemins' },
  { label: 'Magazzini e ubiche', path: warehouses_path, active: false, icon: 'warehouse', can: 'manage_warehouses' },
] %>
<div class="<%= style_main_header_container %>">
  <%= render partial: 'atoms/header', locals: { link: '/', label: 'Seleziona articoli', menu: menu } %>
</div>
```

### Search bar

Same layout as `mainware/index.html.erb`:
- Search input `q` (client-side filter + server-side)
- Collection select dropdown (`collection_id`)
- Result count badge
- Pagination (same Turbo Frame pattern: `items-table`)

### Table columns (no price history, QR, images, or action buttons)

| Column | Data |
|---|---|
| Checkbox | `<input type="checkbox">` with data attributes for basket |
| Gencode | `itemcode + fabricode + varcode` |
| Item | `itemcode` |
| Fabric | `fabricode` |
| Var | `varcode` |
| Descrizione | `description` |
| Tg | `tg` |
| Fabric | `fabric` |
| Color | `colour` |
| Materiale | `materiale` |
| Note | `note` |
| Collezione | `collection.description` |

### Table row partial

New partial `app/views/inventories/_seleziona_item_row.html.erb`. Each `<tr>` has:

```html
<input type="checkbox"
       data-seleziona-target="checkbox"
       data-id="<%= item.id %>"
       data-gencode="<%= item.gencode %>"
       data-collection-id="<%= item.collection_id %>"
       data-collection="<%= item.collection&.description %>"
       data-itemcode="<%= item.itemcode %>">
```

### Stimulus controller: `seleziona`

Controller `app/javascript/controllers/seleziona_controller.js` manages the basket.

**Targets:** `checkbox`, `basket`, `basketCount`, `basketItems`, `qtyInput`

**Basket structure:** fixed horizontal bar at top (`position: fixed; top: 0; z-index: 40`)

**Actions:**
- `checkboxChanged` — when a checkbox is toggled, add/remove from basket array
- `updateQty` — when qty input in basket changes, update the stored qty
- `proceedToCarico` — store selection in a form, submit to `app/in_warehouse`

### Basket bar (fixed top)

```
┌──────────────────────────────────────────────────────────────┐
│  🛒 3 articoli selezionati                                  │
│  [GENCODE1] qty:[1]  [GENCODE2] qty:[2]  [GENCODE3] qty:[1] │
│  [×] [×] [×]                               [Vai a Carico →] │
└──────────────────────────────────────────────────────────────┘
```

Each selected item shows as a chip with:
- Gencode (text)
- Quantity input (number, min 1, default 1)
- Remove button (×)
- Collection name (small text)

### Proceeding to in_warehouse

The "Vai a Carico" button submits a form with the selected items:

```ruby
# In the seleziona Stimulus controller, on proceed:
# Store selected items in session via a POST to the controller
```

Or simpler: POST to a `prepare_carico` action that stores in session and redirects to `app/in_warehouse`.

**Actual approach:**
- Add a POST route: `POST /inventories/seleziona/prepare_carico` → stores `params[:selected_items]` in session as `session[:carico_prefill]`
- Redirects to `app/in_warehouse`
- `AppController#in_warehouse` (GET) reads `session[:carico_prefill]` and builds initial `itemins_details` rows
- On successful save, clear `session[:carico_prefill]`

The session data format:
```ruby
session[:carico_prefill] = [
  { "item_id" => "123", "gencode" => "ABC123_1", "collection_id" => "5", "qty" => "10" },
  { "item_id" => "456", "gencode" => "DEF456_2", "collection_id" => "3", "qty" => "5" },
]
```

### Page layout

The main section needs `padding-top` to account for the fixed basket bar (about 80px).

## Inventory Dashboard link

Add a "Seleziona" tile/link to `inventories/dashboard.html.erb` that points to `inventories_seleziona_path`.

## Files to create/modify

| File | Action |
|---|---|
| `app/controllers/inventories_controller.rb` | Add `seleziona` and `prepare_carico` actions |
| `app/views/inventories/seleziona.html.erb` | Create (main page) |
| `app/views/inventories/_seleziona_item_row.html.erb` | Create (table row partial) |
| `app/javascript/controllers/seleziona_controller.js` | Create (Stimulus controller) |
| `app/controllers/app_controller.rb` | Modify `in_warehouse` action to read `session[:carico_prefill]` |
| `app/views/inventories/dashboard.html.erb` | Add "Seleziona" link |
| `config/routes.rb` | Add `seleziona` and `prepare_carico` routes |

## Data flow diagram

```
[Seleziona page]  ─check/uncheck─→  [Basket bar]
                                        │
                                   [Vai a Carico]
                                        │
                              POST /inventories/seleziona/prepare_carico
                                        │
                              session[:carico_prefill] = [...]
                                        │
                              redirect_to app_in_warehouse_path
                                        │
                              [AppController#in_warehouse GET]
                                        │
                              reads session[:carico_prefill]
                                        │
                              builds @itemin.itemins_details rows
                                        │
                              [InWarehouse form pre-filled]
                                        │
                              POST → save → clear session[:carico_prefill]
```
