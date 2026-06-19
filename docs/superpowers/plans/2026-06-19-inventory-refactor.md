# Inventory Refactor Implementation Plan (Revised)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Denormalize stock, unify creation paths, eliminate N+1s, DRY up controllers, and build API foundation for mobile.

**Architecture:** Stock denormalization first (performance foundation), then gencode columns (enables DB lookup), then service unification (consistency), then API layer (mobile enabler), then cleanup (dead code, rqrcode consolidation).

**Tech Stack:** Rails 7.0, SQLite, Minitest, Grape API, RQRCode

---

## Files Overview

### New Files
- `app/models/stock_level.rb`
- `app/services/movement_builder.rb`
- `app/services/qr_parser.rb`
- `app/controllers/api/v1/inventories.rb`
- `app/controllers/api/v1/entities/inventory_detail.rb`
- `config/initializers/rqrcode.rb`
- `db/migrate/*_add_gencode_to_warehouses_and_locations.rb`
- `db/migrate/*_backfill_warehouse_location_gencode.rb`
- `db/migrate/*_create_stock_levels.rb`
- `db/migrate/*_backfill_stock_levels.rb`

### Modified Files
- `app/models/warehouse.rb` — store gencode on save
- `app/models/location.rb` — store gencode on save
- `app/services/create_inventories_from_itemin.rb` — StockLevel upsert, remove inline `require 'rqrcode'`
- `app/services/create_inventories_from_itemout.rb` — StockLevel upsert
- `app/services/create_inventories_from_itemmovement.rb` — StockLevel upserts (2 deltas)
- `app/services/import_inventory_service.rb` — delegate to standard services
- `app/controllers/inventories_controller.rb` — StockLevel for main list, keep history queries, autocomplete
- `app/controllers/warehouses_controller.rb` — `find_by(gencode:)` after column exists
- `app/controllers/itemins_controller.rb` — MovementBuilder
- `app/controllers/app_controller.rb` — MovementBuilder, transaction wrapping, menu links, list view redirects
- `app/views/inventories/index.html.erb` — `net_qty` → `current_qty`
- `config/routes.rb` — dead routes removed, API mount, list view redirects
- `db/seeds.rb` — remove `manage_basic_qr_codes` ability
- `Gemfile` — add `rack-cors`
- `app/models/item.rb` — remove inline `require 'rqrcode'`

### Deleted Files
- `app/services/check_qr_code_service.rb`
- `app/controllers/basic_qr_codes_controller.rb`
- `app/views/app/itemins_list.html.erb`
- `app/views/app/itemouts_list.html.erb`
- `app/views/app/itemmovements_list.html.erb`

---

## Task Structure

### Phase 0: Gencode Columns — Enable DB Lookup (Pre-requisite)

This MUST be done before Phase 2 Task 6. `Warehouse.find_by(gencode: q)` requires `gencode` as a real DB column.

### Task 0: Add real gencode columns to warehouses and locations

**Files:**
- Create: `db/migrate/*_add_gencode_to_warehouses_and_locations.rb`
- Create: `db/migrate/*_backfill_warehouse_location_gencode.rb`
- Modify: `app/models/warehouse.rb`
- Modify: `app/models/location.rb`

- [ ] **Step 1: Write add-column migration**

```ruby
# db/migrate/20260619124000_add_gencode_to_warehouses_and_locations.rb
class AddGencodeToWarehousesAndLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :warehouses, :gencode, :string
    add_column :locations,  :gencode, :string
    add_index :warehouses, :gencode
    add_index :locations,  :gencode
  end
end
```

- [ ] **Step 2: Write backfill migration**

```ruby
# db/migrate/20260619124100_backfill_warehouse_location_gencode.rb
class BackfillWarehouseLocationGencode < ActiveRecord::Migration[7.0]
  def up
    Warehouse.find_each { |w| w.update_columns(gencode: "#{w.id}_#{w.code}") }
    Location.find_each  { |l| l.update_columns(gencode: "#{l.warehouse_id}_#{l.id}_#{l.code}") }
  end

  def down
    Warehouse.update_all(gencode: nil)
    Location.update_all(gencode: nil)
  end
end
```

- [ ] **Step 3: Update Warehouse model to persist gencode**

In `app/models/warehouse.rb`, modify the `generate_qr_code` callback to also store `gencode`:

```ruby
# app/models/warehouse.rb (modified callbacks)
def generate_qr_code
  require 'rqrcode'
  self.gencode = "#{id}_#{code}"
  self.qrcode_svg = RQRCode::QRCode.new(gencode).as_svg(
    module_size: 6, use_path: true, viewbox: true
  ).sub(/^<\?xml[^>]*>/, "")
end
```

Same pattern for `app/models/location.rb`:

```ruby
# app/models/location.rb (modified callbacks)
def generate_qr_code
  require 'rqrcode'
  self.gencode = "#{warehouse_id}_#{id}_#{code}"
  self.qrcode_svg = RQRCode::QRCode.new(gencode).as_svg(
    module_size: 6, use_path: true, viewbox: true
  ).sub(/^<\?xml[^>]*>/, "")
end
```

- [ ] **Step 4: Run migrations**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Verify**

Run: `bin/rails runner 'puts Warehouse.pluck(:id, :code, :gencode).inspect; puts Location.pluck(:id, :code, :gencode).inspect'`

- [ ] **Step 6: Commit**

```bash
git add db/migrate/*_add_gencode_to_warehouses_and_locations.rb db/migrate/*_backfill_warehouse_location_gencode.rb app/models/warehouse.rb app/models/location.rb
git commit -m "feat: add real gencode columns to warehouses/locations with backfill"
```

---

### Phase 1: Foundation — Stock Denormalization

### Task 1: Create StockLevel model and migration

**Files:**
- Create: `db/migrate/*_create_stock_levels.rb`
- Create: `app/models/stock_level.rb`

- [ ] **Step 1: Write migration**

**FIXED (P1):** `location_id` is now `null: false, default: 0` to avoid SQLite NULL ambiguity in unique index.

```ruby
# db/migrate/20260619130000_create_stock_levels.rb
class CreateStockLevels < ActiveRecord::Migration[7.0]
  def change
    create_table :stock_levels do |t|
      t.string  :gencode,       null: false
      t.integer :warehouse_id,  null: false
      t.integer :location_id,   null: false, default: 0
      t.integer :current_qty,   null: false, default: 0
      t.timestamps
    end

    add_index :stock_levels, [:gencode, :warehouse_id, :location_id],
              unique: true,
              name: "idx_stock_levels_unique"
    add_index :stock_levels, :gencode
    add_index :stock_levels, :warehouse_id
  end
end
```

- [ ] **Step 2: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 3: Create StockLevel model**

```ruby
# app/models/stock_level.rb
class StockLevel < ApplicationRecord
  belongs_to :warehouse
  belongs_to :location, optional: true

  scope :positive, -> { where("current_qty > 0") }
end
```

- [ ] **Step 4: Run test**

Run: `bin/rails test test/models/stock_level_test.rb`

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_create_stock_levels.rb app/models/stock_level.rb
git commit -m "feat: add StockLevel model for denormalized current stock"
```

### Task 2: Add StockLevel upserts to all Inventory creation services

**Files:**
- Modify: `app/services/create_inventories_from_itemin.rb`
- Modify: `app/services/create_inventories_from_itemout.rb`
- Modify: `app/services/create_inventories_from_itemmovement.rb`

**NOTE (P2):** StockLevel upserts run AFTER `Inventory.create!` inside the same each-loop iteration. The caller wraps everything in `ActiveRecord::Base.transaction`, so rollback is automatic. This dependency is critical — do NOT move the upsert outside the transaction boundary.

- [ ] **Step 1: Add upsert to CreateInventoriesFromItemin**

```ruby
# app/services/create_inventories_from_itemin.rb
class CreateInventoriesFromItemin
  def call(itemin)
    records = []
    item_ids = itemin.itemins_details.map(&:item_id).compact.uniq
    items = Item.where(id: item_ids).index_by(&:id)
    qr_service = CreateQrService.new

    itemin.itemins_details.each do |detail|
      gencode = items[detail.item_id]&.gencode
      qr_code = "#{gencode}_#{detail.id}"
      qr_svg = qr_service.svg(qr_code)

      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        operationtype_id: detail.operationtype_id,
        itemins_id: itemin.id,
        qrcode_svg: qr_svg,
        enabled: true
      )

      # NOTE: Caller MUST wrap in ActiveRecord::Base.transaction
      # Upsert is atomic via Arel.sql — no race conditions
      StockLevel.upsert({
        gencode: gencode,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id || 0,
        current_qty: Arel.sql("COALESCE(current_qty, 0) + #{detail.qty.to_i}")
      }, unique_by: [:gencode, :warehouse_id, :location_id])
    end
    records
  end
end
```

- [ ] **Step 2: Add upsert to CreateInventoriesFromItemout**

```ruby
# app/services/create_inventories_from_itemout.rb
class CreateInventoriesFromItemout
  def call(itemout)
    records = []
    item_ids = itemout.itemouts_details.map(&:item_id).compact.uniq
    items = Item.where(id: item_ids).index_by(&:id)

    itemout.itemouts_details.each do |detail|
      gencode = items[detail.item_id]&.gencode
      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        operationtype_id: detail.operationtype_id,
        itemouts_id: itemout.id,
        enabled: true
      )

      StockLevel.upsert({
        gencode: gencode,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id || 0,
        current_qty: Arel.sql("COALESCE(current_qty, 0) - #{detail.qty.to_i}")
      }, unique_by: [:gencode, :warehouse_id, :location_id])
    end
    records
  end
end
```

- [ ] **Step 3: Add upserts to CreateInventoriesFromItemmovement**

```ruby
# app/services/create_inventories_from_itemmovement.rb
class CreateInventoriesFromItemmovement
  def call(itemmovement)
    records = []
    item_ids = itemmovement.itemmovements_details.map(&:item_id).compact.uniq
    items = Item.where(id: item_ids).index_by(&:id)

    itemmovement.itemmovements_details.each do |detail|
      gencode = items[detail.item_id]&.gencode

      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        operationtype_id: 2,
        itemmovement_id: itemmovement.id,
        enabled: true
      )

      StockLevel.upsert({
        gencode: gencode,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id || 0,
        current_qty: Arel.sql("COALESCE(current_qty, 0) - #{detail.qty.to_i}")
      }, unique_by: [:gencode, :warehouse_id, :location_id])

      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: itemmovement.dest_warehouse_id,
        location_id: itemmovement.dest_location_id,
        operationtype_id: 1,
        itemmovement_id: itemmovement.id,
        enabled: true
      )

      StockLevel.upsert({
        gencode: gencode,
        warehouse_id: itemmovement.dest_warehouse_id,
        location_id: itemmovement.dest_location_id || 0,
        current_qty: Arel.sql("COALESCE(current_qty, 0) + #{detail.qty.to_i}")
      }, unique_by: [:gencode, :warehouse_id, :location_id])
    end
    records
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add app/services/create_inventories_from_itemin.rb app/services/create_inventories_from_itemout.rb app/services/create_inventories_from_itemmovement.rb
git commit -m "feat: add StockLevel upserts to all inventory creation services"
```

### Task 3: Update ImportInventoryService to use standard services

**Files:**
- Modify: `app/services/import_inventory_service.rb`

- [ ] **Step 1: Replace direct Inventory creation with service delegation**

The old code at lines 97-114 directly created Inventory records and set `minstock`/`maxstock` from Excel rows. The replacement delegates to `CreateInventoriesFromItemin`/`CreateInventoriesFromItemout`, which also handles StockLevel upserts. `minstock`/`maxstock` are optional Excel fields — they are dropped from this refactor but can be re-added later from the movement detail attributes.

```ruby
# app/services/import_inventory_service.rb (save method, replaces lines 50-128)
def save(data, user = nil)
  stats = { total: data[:rows].size, created: 0, errors: [], items: [], skipped: [], invalid: [] }
  op_type_id = data[:operationtype_id].to_i

  return stats unless [1, 2].include?(op_type_id)

  warehouse = Warehouse.find(data[:warehouse_id])

  ActiveRecord::Base.transaction do
    movement = if op_type_id == 1
      Itemin.new(indate: Date.current, operator_id: user&.id, notes: "Importazione Excel")
    else
      Itemout.new(indate: Date.current, operator_id: user&.id, notes: "Importazione Excel")
    end

    valid_rows = []

    data[:rows].each_with_index do |row, i|
      unless row[:_valid]
        itemcode = row['Item Code:'] || row['itemcode'] || row['Item Code']
        stats[:invalid] << { itemcode: itemcode, row: row[:_index], error: row[:_error] }
        next
      end

      itemcode = row['Item Code:'] || row['itemcode'] || row['Item Code']
      qty = (row['Qt.'] || row['Quantity'] || row['qtyavailable'] || row['QTA'] || 0).to_i

      if qty == 0
        stats[:skipped] << { itemcode: itemcode, row: row[:_index] }
        next
      end

      detail_attrs = {
        itemcode: itemcode,
        qty: qty,
        warehouse: warehouse,
        location_id: data[:location_id].presence,
        operationtype_id: op_type_id
      }

      if op_type_id == 1
        movement.itemins_details.build(detail_attrs)
      else
        movement.itemouts_details.build(detail_attrs)
      end

      valid_rows << row
    end

    movement.save!

    inventory_records = if op_type_id == 1
      CreateInventoriesFromItemin.new.call(movement)
    else
      CreateInventoriesFromItemout.new.call(movement)
    end

    details = op_type_id == 1 ? movement.itemins_details : movement.itemouts_details
    details.each_with_index do |detail, i|
      stats[:items] << { itemcode: detail.itemcode, qty: detail.qty, inventory_id: i }
      stats[:created] += 1
    end
  end

  stats
rescue => e
  error_msg = if e.respond_to?(:record) && e.record
    e.record.errors.full_messages.join(", ")
  elsif e.message.include?("record_invalid")
    "Validazione fallita"
  else
    e.message
  end
  stats[:errors] << { row: 0, error: error_msg }
  stats
end
```

- [ ] **Step 2: Commit**

```bash
git add app/services/import_inventory_service.rb
git commit -m "refactor: ImportInventoryService delegates to standard services"
```

### Task 4: Backfill existing stock levels

**Files:**
- Create: `db/migrate/*_backfill_stock_levels.rb`

- [ ] **Step 1: Write backfill migration**

```ruby
# db/migrate/20260619140000_backfill_stock_levels.rb
class BackfillStockLevels < ActiveRecord::Migration[7.0]
  def up
    Inventory.select(:gencode, :warehouse_id, :location_id)
      .select(Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty"))
      .group(:gencode, :warehouse_id, :location_id)
      .having("net_qty != 0")
      .find_each do |row|
        StockLevel.upsert(
          gencode: row.gencode,
          warehouse_id: row.warehouse_id,
          location_id: row.location_id || 0,
          current_qty: row.net_qty
        )
      end
  end

  def down
    StockLevel.delete_all
  end
end
```

- [ ] **Step 2: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 3: Verify backfill integrity**

Run a reconciliation check:
```bash
bin/rails runner '
event_log_total = Inventory.select(
  Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS grand_total")
).to_a.first.grand_total.to_i

stock_total = StockLevel.sum(:current_qty)

if event_log_total == stock_total
  puts "[OK] Reconciled: StockLevel total #{stock_total} matches Inventory log total #{event_log_total}"
else
  puts "[FAIL] Mismatch: StockLevel total #{stock_total} != Inventory log total #{event_log_total}"
end
'
```

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_backfill_stock_levels.rb
git commit -m "feat: backfill StockLevel from existing Inventory records"
```

### Task 5: Replace SUM queries with StockLevel reads

**Files:**
- Modify: `app/controllers/inventories_controller.rb` (index, autocomplete, lookup_by_qr legacy)
- Modify: `app/controllers/itemouts_controller.rb`
- Modify: `app/views/inventories/index.html.erb`

- [ ] **Step 1: Replace index query — KEEP history loading**

**FIXED (P3, P4):** The view needs `@history_by_gencode`, `@itemins_by_id`, `@itemouts_by_id`, `@itemmovements_by_id`, `@collection_by_gencode`, `@items_by_gencode`. These are populated from the event log independently of the main `@inventories` list. The solution: use StockLevel for the main list, but keep the history-loading code (controller lines 46-74) as-is.

The view also uses `inv.net_qty` — must change to `inv.current_qty`.

```ruby
# app/controllers/inventories_controller.rb#index (replacement)
def index
  @date = if params[:date].present?
    Date.parse(params[:date]) rescue Date.current
  else
    Date.current
  end

  @warehouses = Warehouse.order(:code)
  @collections = Collection.all

  if params[:date].present? && params[:date].to_date != Date.current
    # Historical date — use event log (slower but accurate)
    base = Inventory.where.not(gencode: nil)
      .left_joins(:itemin, :itemout)
      .where("COALESCE(itemins.indate, itemouts.indate) <= ?", @date)

    if params[:warehouse_id].present?
      base = base.where(warehouse_id: params[:warehouse_id])
    end
    if params[:collection_id].present?
      base = base.joins("INNER JOIN items ON items.gencode = inventories.gencode")
                 .where(items: { collection_id: params[:collection_id] })
    end

    @inventories = base.group(:gencode).select(
      :gencode,
      Arel.sql("MAX(inventories.itemcode) AS itemcode"),
      Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
    ).order(:gencode)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @inventories = @inventories.having("inventories.gencode LIKE :q", q: q)
    end

    count = base.distinct.count(:gencode)
    @pagy, @inventories = pagy(@inventories, count: count)
  else
    # Current stock — use StockLevel (fast)
    @inventories = StockLevel.positive.order(:gencode)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @inventories = @inventories.joins("INNER JOIN items ON items.gencode = stock_levels.gencode")
        .where("items.gencode LIKE :q OR items.itemcode LIKE :q", q: q)
    end

    if params[:warehouse_id].present?
      @inventories = @inventories.where(warehouse_id: params[:warehouse_id])
    end

    if params[:collection_id].present?
      @inventories = @inventories.joins("INNER JOIN items ON items.gencode = stock_levels.gencode")
        .where(items: { collection_id: params[:collection_id] })
    end

    count = @inventories.distinct.count(:gencode)
    @pagy, @inventories = pagy(@inventories, count: count)
  end

  # History loading — KEPT from original (lines 46-74), works for both branches
  gencodes = @inventories.map(&:gencode).compact
  @history_by_gencode = {}
  history_records = Inventory.where(gencode: gencodes)
    .left_joins(:itemin, :itemout, :itemmovement)
    .where("COALESCE(itemins.indate, itemouts.indate, itemmovements.indate) <= ?", @date)
    .includes(:warehouse, :location, :operationtype)
    .order(Arel.sql("COALESCE(itemins.indate, itemouts.indate, itemmovements.indate) ASC, inventories.created_at ASC"))

  if params[:warehouse_id].present?
    history_records = history_records.where(warehouse_id: params[:warehouse_id])
  end

  itemin_ids = history_records.map(&:itemins_id).compact.uniq
  itemout_ids = history_records.map(&:itemouts_id).compact.uniq
  itemmovement_ids = history_records.map(&:itemmovement_id).compact.uniq
  @itemins_by_id = Itemin.includes(:operator).where(id: itemin_ids).index_by(&:id)
  @itemouts_by_id = Itemout.includes(:operator).where(id: itemout_ids).index_by(&:id)
  @itemmovements_by_id = Itemmovement.includes(:operator, :source_warehouse, :dest_warehouse, :source_location, :dest_location).where(id: itemmovement_ids).index_by(&:id)

  history_records.group_by(&:gencode).each do |gencode, records|
    @history_by_gencode[gencode] = records.group_by(&:warehouse_id).transform_values do |wh_records|
      wh_records.group_by { |r| r.location_id || 0 }.transform_values do |loc_records|
        loc_records.partition { |r| !r.itemmovement_id }.flatten
      end
    end
  end

  items = Item.where(gencode: gencodes).includes(:collection).with_attached_pictures.index_by(&:gencode)
  @collection_by_gencode = items.transform_values { |item| item.collection&.description }
  @items_by_gencode = items
end
```

- [ ] **Step 2: Fix view — net_qty → current_qty**

In `app/views/inventories/index.html.erb`, find `inv.net_qty.to_i` (line 72) and change to `inv.current_qty`:

```erb
<!-- app/views/inventories/index.html.erb line 72 -->
<!-- Change: inv.net_qty.to_i → inv.current_qty -->
<%= inv.current_qty %>
```

If the historical date branch uses `inv.net_qty` (from the Arel alias), the view must handle both. Use a conditional:

```erb
<%= inv.respond_to?(:current_qty) ? inv.current_qty : inv.net_qty.to_i %>
```

- [ ] **Step 3: Replace autocomplete SUM query**

```ruby
# app/controllers/inventories_controller.rb#autocomplete (replace lines 104-110)
stock_levels = StockLevel.where(gencode: inventories.map(&:gencode).uniq)
net_qty_by_key = stock_levels.each_with_object({}) { |sl, h|
  h[[sl.gencode, sl.warehouse_id, sl.location_id]] = sl.current_qty
}
# Remove the old Inventory.where(...).group(...).select(Arel.sql(...))
```

- [ ] **Step 4: Replace lookup_by_qr legacy SUM query**

```ruby
# app/controllers/inventories_controller.rb#legacy_qr_result (replace SUM query)
positions = StockLevel.where(gencode: item.gencode).positive.includes(:warehouse, :location)

{
  format: "legacy",
  item: item_summary(item),
  positions: positions.map { |sl|
    {
      warehouse_id: sl.warehouse_id,
      location_id: sl.location_id,
      warehouse: sl.warehouse&.code,
      location: sl.location&.code,
      net_qty: sl.current_qty
    }
  }
}
```

- [ ] **Step 5: Replace itemouts_controller bulk SUM**

In `app/controllers/itemouts_controller.rb`, replace the bulk `net_qty_by_key` query (lines 114-120) with a StockLevel lookup:

```ruby
# app/controllers/itemouts_controller.rb (replaces lines 114-120)
stock = StockLevel.where(gencode: gencodes)
  .each_with_object({}) { |sl, h| h[[sl.gencode, sl.warehouse_id, sl.location_id]] = sl.current_qty }
```

- [ ] **Step 6: Commit**

```bash
git add app/controllers/inventories_controller.rb app/controllers/itemouts_controller.rb app/views/inventories/index.html.erb
git commit -m "perf: replace SUM queries with StockLevel reads, keep history loading"
```

---

### Phase 2: Fix N+1s and Dead Code

### Task 6: Fix warehouses_controller lookup_by_qr N+1

**Files:**
- Modify: `app/controllers/warehouses_controller.rb`

**FIXED (P7):** `gencode` is now a real DB column (from Phase 0). `find_by(gencode: q)` works.

- [ ] **Step 1: Replace Ruby iteration with DB queries**

```ruby
# app/controllers/warehouses_controller.rb (replaces lines 19-42)
def lookup_by_qr
  q = params[:q].to_s.strip
  result = { warehouse_id: nil, warehouse_code: nil, location_id: nil, location_code: nil }

  warehouse = Warehouse.find_by(gencode: q)
  if warehouse
    result[:warehouse_id] = warehouse.id
    result[:warehouse_code] = warehouse.code
  else
    location = Location.find_by(gencode: q)
    if location
      result[:location_id] = location.id
      result[:location_code] = location.code
      result[:warehouse_id] = location.warehouse_id
      result[:warehouse_code] = location.warehouse&.code
    end
  end

  render json: result
end
```

- [ ] **Step 2: Commit**

```bash
git add app/controllers/warehouses_controller.rb
git commit -m "perf: fix warehouses lookup_by_qr N+1, use direct DB queries on gencode column"
```

### Task 7: Delete dead code

**Files:**
- Delete: `app/services/check_qr_code_service.rb`
- Delete: `app/controllers/basic_qr_codes_controller.rb`
- Modify: `config/routes.rb`
- Modify: `db/seeds.rb`

**FIXED (P8):** Also remove `manage_basic_qr_codes` from seeds.

- [ ] **Step 1: Remove dead service**

```bash
git rm app/services/check_qr_code_service.rb
```

- [ ] **Step 2: Remove dead controller**

```bash
git rm app/controllers/basic_qr_codes_controller.rb
```

- [ ] **Step 3: Remove routes and seeds reference**

Remove from `config/routes.rb` (lines 179-180):
```ruby
# DELETE these lines:
get 'basic-qr-code-reader', to: 'basic_qr_codes#index'
get 'basic_qr_codes/qrcheck'
```

Remove from `db/seeds.rb` (line 25):
```ruby
# DELETE this line:
{ name: 'manage_basic_qr_codes', description: 'Gestione QR reader', controller_name: 'basic_qr_codes', action: '' },
```

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb db/seeds.rb
git commit -m "chore: remove dead code (check_qr_code_service, basic_qr_codes_controller) and orphaned seed"
```

---

### Phase 3: DRY Up Controllers

### Task 8: Extract MovementBuilder service

**Files:**
- Create: `app/services/movement_builder.rb`
- Modify: `app/controllers/app_controller.rb`
- Modify: `app/controllers/itemins_controller.rb`

- [ ] **Step 1: Create MovementBuilder**

**FIXED (P9, P10, P12):**
- Uses explicit `DETAIL_ASSOCIATIONS` map instead of non-existent `details` association
- Calls `.to_unsafe_h` on params to avoid `ForbiddenAttributesError`
- Sets default `operationtype_id` per movement class

```ruby
# app/services/movement_builder.rb
class MovementBuilder
  DETAIL_ASSOCIATIONS = {
    Itemin        => :itemins_details,
    Itemout       => :itemouts_details,
    Itemmovement  => :itemmovements_details
  }.freeze

  DEFAULT_OPERATION = {
    Itemin        => 1,
    Itemout       => 2,
    Itemmovement  => nil  # set per form
  }.freeze

  def initialize(movement_class, params, defaults: {})
    @movement_class = movement_class
    @details_assoc   = DETAIL_ASSOCIATIONS.fetch(movement_class)
    @params          = params
    @defaults        = defaults
  end

  def build
    movement = @movement_class.new(header_params)
    build_details.each { |d| movement.send(@details_assoc).build(d) }
    movement
  end

  private

  def header_params
    @params.to_unsafe_h.except(
      :details_attributes,
      :itemins_details_attributes,
      :itemouts_details_attributes,
      :itemmovements_details_attributes
    )
  end

  def build_details
    details_attr_key = detect_details_key
    return [] unless details_attr_key

    (@params.to_unsafe_h[details_attr_key.to_s]&.values || [])
      .reject { |d| d["_destroy"] == "1" || d[:_destroy] == "1" }
      .reject { |d| d["itemcode"].blank? && d["item_id"].blank? &&
                     d[:itemcode].blank?  && d[:item_id].blank? }
      .map { |d| d.symbolize_keys.except(:_destroy, "_destroy") }
      .map { |d| apply_defaults(d) }
  end

  def detect_details_key
    [:details_attributes, :itemins_details_attributes,
     :itemouts_details_attributes, :itemmovements_details_attributes].each do |key|
      return key if @params[key].present?
    end
    nil
  end

  def apply_defaults(detail)
    detail[:collection_id]   ||= @defaults[:collection_id]   if @defaults[:collection_id].present?
    detail[:warehouse_id]    ||= @defaults[:warehouse_id]    if @defaults[:warehouse_id].present?
    detail[:location_id]     ||= @defaults[:location_id]     if @defaults[:location_id].present?
    detail[:operationtype_id] ||= DEFAULT_OPERATION[@movement_class]
    detail
  end
end
```

- [ ] **Step 2: Replace copy-pasted blocks in AppController**

In `app/controllers/app_controller.rb`, replace the detail rejection + default logic in `in_warehouse`, `out_warehouse`, `move_products`.

For `in_warehouse` (lines 65-82):
```ruby
def in_warehouse
  if request.post?
    @itemin = MovementBuilder.new(
      Itemin, params[:itemin],
      defaults: {
        collection_id: params[:default_collection_id],
        warehouse_id: params[:default_warehouse_id],
        location_id: params[:default_location_id]
      }
    ).build

    ActiveRecord::Base.transaction do
      @itemin.save!
      CreateInventoriesFromItemin.new.call(@itemin)
    end

    redirect_to app_in_warehouse_confirmation_path(itemin_id: @itemin.id, from_seleziona: params[:from_seleziona])
  else
    ...
  end
end
```

**FIXED (M5):** Wrapped in `ActiveRecord::Base.transaction` — if `CreateInventoriesFromItemin` fails, the `Itemin` save rolls back too.

Same pattern for `out_warehouse` (with `Itemout` and `CreateInventoriesFromItemout`) and `move_products` (with `Itemmovement` and `CreateInventoriesFromItemmovement`). Remove all manual `.reject/.map` blocks.

- [ ] **Step 3: Replace in IteminsController**

```ruby
# app/controllers/itemins_controller.rb#confirm (replace lines 70-88)
@itemin = MovementBuilder.new(Itemin, @params).build

ActiveRecord::Base.transaction do
  @itemin.save!
  CreateInventoriesFromItemin.new.call(@itemin)
end

session.delete(:itemin_preview)
redirect_to inventories_dashboard_path, notice: "Carico creato con #{@itemin.itemins_details.size} articoli"
```

- [ ] **Step 4: Commit**

```bash
git add app/services/movement_builder.rb app/controllers/app_controller.rb app/controllers/itemins_controller.rb
git commit -m "refactor: extract MovementBuilder service with correct association handling"
```

### Task 9: Merge triplicate list views + fix menu links

**Files:**
- Modify: `app/controllers/app_controller.rb`
- Modify: `config/routes.rb`
- Delete: `app/views/app/itemins_list.html.erb`, `itemouts_list.html.erb`, `itemmovements_list.html.erb`

**FIXED (P13, P14):** Keep as redirects (not removal) to avoid broken menu links. Update menu helper to point to `inventories_movements_path`.

- [ ] **Step 1: Replace list methods with redirects**

```ruby
# app/controllers/app_controller.rb (replace itemins_list, itemouts_list, itemmovements_list)
def itemins_list
  redirect_to inventories_movements_path(operationtype_id: 1)
end

def itemouts_list
  redirect_to inventories_movements_path(operationtype_id: 2)
end

def itemmovements_list
  redirect_to inventories_movements_path(operationtype_id: 3)
end
```

- [ ] **Step 2: Update menu helper**

In `app/controllers/app_controller.rb`, find the `set_app_menu` or equivalent method that uses `app_itemins_list_path`, `app_itemouts_list_path`, `app_itemmovements_list_path` (around line 349-351). Replace with:

```ruby
{ label: 'Carichi', path: app_itemins_list_path, ... },
# becomes:
{ label: 'Carichi', path: inventories_movements_path(operationtype_id: 1), ... },
```

- [ ] **Step 3: Remove old view files**

```bash
git rm app/views/app/itemins_list.html.erb
git rm app/views/app/itemouts_list.html.erb
git rm app/views/app/itemmovements_list.html.erb
```

- [ ] **Step 4: Commit**

```bash
git add app/controllers/app_controller.rb config/routes.rb
git commit -m "refactor: redirect triplicate list views to InventoriesController#movements"
```

---

### Phase 4: Extract Shared QR Parser + Consolidate requires

### Task 10: Extract QR parsing to shared service

**Files:**
- Create: `app/services/qr_parser.rb`
- Modify: `app/controllers/inventories_controller.rb`
- Modify: `app/controllers/mainware_controller.rb`

`extract_gencode_and_detail_id` is duplicated in `InventoriesController` and `MainwareController`. Extract it once. Later the API will also use it.

- [ ] **Step 1: Create QrParser service**

```ruby
# app/services/qr_parser.rb
class QrParser
  def self.parse(text)
    if text =~ /\A(.+)_(\d+)\z/
      candidate_gencode = $1
      candidate_detail_id = $2.to_i
      if candidate_gencode =~ /_(\d+)\z/
        return { gencode: candidate_gencode, detail_id: candidate_detail_id }
      end
    end
    { gencode: text, detail_id: nil }
  end
end
```

- [ ] **Step 2: Replace in InventoriesController**

```ruby
# app/controllers/inventories_controller.rb#parse_qr_code (simplified)
def parse_qr_code(scanned_text)
  parsed = QrParser.parse(scanned_text)

  item = Item.find_by(gencode: parsed[:gencode])
  return { error: "Item not found" } unless item

  if parsed[:detail_id]
    detail = IteminsDetail.find_by(id: parsed[:detail_id])
    if detail
      return itemins_qr_result(item, detail)
    end
  end

  legacy_qr_result(item)
end
```

- [ ] **Step 3: Replace in MainwareController**

```ruby
# app/controllers/mainware_controller.rb#parse_qr_gencode
def parse_qr_gencode(text)
  QrParser.parse(text)[:gencode]
end
```

- [ ] **Step 4: Commit**

```bash
git add app/services/qr_parser.rb app/controllers/inventories_controller.rb app/controllers/mainware_controller.rb
git commit -m "refactor: extract QrParser service, remove duplicate QR parsing logic"
```

### Task 11: Consolidate require 'rqrcode'

**Files:**
- Create: `config/initializers/rqrcode.rb`
- Modify: `app/models/item.rb`
- Modify: `app/models/warehouse.rb`
- Modify: `app/models/location.rb`
- Modify: `app/services/create_inventories_from_itemin.rb`

- [ ] **Step 1: Create initializer**

```ruby
# config/initializers/rqrcode.rb
require 'rqrcode'
```

- [ ] **Step 2: Remove inline requires**

Remove `require 'rqrcode'` from:
- `app/models/item.rb:24`
- `app/models/warehouse.rb:12`
- `app/models/location.rb:11`
- `app/services/create_inventories_from_itemin.rb:2` (already removed in Task 2)
- `app/services/create_qr_service.rb:2` (keep — standalone service, harmless)

- [ ] **Step 3: Commit**

```bash
git add config/initializers/rqrcode.rb app/models/item.rb app/models/warehouse.rb app/models/location.rb app/services/create_inventories_from_itemin.rb
git commit -m "chore: consolidate require 'rqrcode' into initializer"
```

---

### Phase 5: Mobile API Layer

### Task 12: Build Grape API inventory endpoints

**Files:**
- Create: `app/controllers/api/v1/inventories.rb`
- Create: `app/controllers/api/v1/entities/inventory_detail.rb`
- Modify: `app/controllers/api/v1/base.rb` — mount new module
- Modify: `config/routes.rb`
- Modify: `Gemfile` — add `rack-cors`

**FIXED (P15, P16, P17, P21):**
- Mount inside `API::V1::Base` with `mount API::V1::Inventories` (no `at:` needed — the resource handles routing)
- Add `rack-cors` to Gemfile
- Transfer groups by all 4 keys (source + dest) — fixed P21

- [ ] **Step 1: Add rack-cors to Gemfile**

```ruby
# Gemfile (add line)
gem 'rack-cors'
```

Run: `bundle install`

- [ ] **Step 2: Create API module**

```ruby
# app/controllers/api/v1/inventories.rb
module API
  module V1
    class Inventories < Grape::API
      include API::V1::Defaults

      resource :inventories do

        # GET /api/v1/inventories/lookup?q=gencode_or_qr_text
        params do
          requires :q, type: String, desc: "Scanned QR text or gencode"
        end
        get :lookup do
          text = params[:q].to_s.strip
          parsed = QrParser.parse(text)

          item = Item.find_by(gencode: parsed[:gencode])
          error!("Item not found", 404) unless item

          stock = StockLevel.where(gencode: parsed[:gencode]).positive.includes(:warehouse, :location)

          inbound = nil
          if parsed[:detail_id]
            detail = IteminsDetail.find_by(id: parsed[:detail_id])
            inbound = {
              warehouse_id: detail.warehouse_id,
              location_id: detail.location_id,
              warehouse: detail.warehouse&.code,
              location: detail.location&.code
            } if detail
          end

          present :item, {
            id: item.id, gencode: item.gencode, itemcode: item.itemcode,
            fabricode: item.fabricode, varcode: item.varcode,
            description: item.description, collection: item.collection&.description
          }
          present :stock, stock.map { |sl|
            { warehouse_id: sl.warehouse_id, location_id: sl.location_id,
              warehouse: sl.warehouse&.code, location: sl.location&.code,
              current_qty: sl.current_qty }
          }
          present :inbound, inbound if inbound
        end

        # POST /api/v1/inventories/inbound
        params do
          requires :details, type: Array do
            requires :gencode, type: String
            requires :qty, type: Integer, values: ->(v) { v > 0 }
            optional :warehouse_id, type: Integer
            optional :location_id, type: Integer
          end
          optional :indate, type: Date, default: -> { Date.current }
          optional :operator_id, type: Integer
          optional :notes, type: String
        end
        post :inbound do
          itemin = Itemin.new(indate: params[:indate], operator_id: params[:operator_id], notes: params[:notes])

          params[:details].each do |d|
            item = Item.find_by(gencode: d[:gencode])
            error!("Item #{d[:gencode]} not found", 404) unless item

            itemin.itemins_details.build(
              itemcode: d[:gencode], qty: d[:qty], item_id: item.id,
              warehouse_id: d[:warehouse_id], location_id: d[:location_id],
              operationtype_id: 1
            )
          end

          ActiveRecord::Base.transaction do
            itemin.save!
            CreateInventoriesFromItemin.new.call(itemin)
          end

          present :id, itemin.id
          present :details_count, itemin.itemins_details.size
        end

        # POST /api/v1/inventories/outbound
        params do
          requires :details, type: Array do
            requires :gencode, type: String
            requires :qty, type: Integer, values: ->(v) { v > 0 }
            requires :warehouse_id, type: Integer
            requires :location_id, type: Integer
          end
          optional :indate, type: Date, default: -> { Date.current }
          optional :operator_id, type: Integer
        end
        post :outbound do
          params[:details].each do |d|
            sl = StockLevel.find_by(gencode: d[:gencode], warehouse_id: d[:warehouse_id], location_id: d[:location_id] || 0)
            error!("Insufficient stock for #{d[:gencode]} at WH##{d[:warehouse_id]}/LOC##{d[:location_id]}: available #{sl&.current_qty || 0}, requested #{d[:qty]}", 422) unless sl && sl.current_qty >= d[:qty]
          end

          itemout = Itemout.new(indate: params[:indate], operator_id: params[:operator_id])

          params[:details].each do |d|
            item = Item.find_by(gencode: d[:gencode])
            error!("Item #{d[:gencode]} not found", 404) unless item

            itemout.itemouts_details.build(
              itemcode: d[:gencode], qty: d[:qty], item_id: item.id,
              warehouse_id: d[:warehouse_id], location_id: d[:location_id],
              operationtype_id: 2
            )
          end

          ActiveRecord::Base.transaction do
            itemout.save!
            CreateInventoriesFromItemout.new.call(itemout)
          end

          present :id, itemout.id
          present :details_count, itemout.itemouts_details.size
        end

        # POST /api/v1/inventories/transfer
        params do
          requires :details, type: Array do
            requires :gencode, type: String
            requires :qty, type: Integer, values: ->(v) { v > 0 }
            requires :source_warehouse_id, type: Integer
            requires :source_location_id, type: Integer
            requires :dest_warehouse_id, type: Integer
            requires :dest_location_id, type: Integer
          end
          optional :indate, type: Date, default: -> { Date.current }
          optional :operator_id, type: Integer
        end
        post :transfer do
          items_by_gencode = Item.where(gencode: params[:details].map { |d| d[:gencode] }).index_by(&:gencode)

          # FIXED P21: group by all four keys (source + dest)
          params[:details].group_by { |d|
            [d[:source_warehouse_id], d[:source_location_id],
             d[:dest_warehouse_id], d[:dest_location_id]]
          }.each do |(src_wh, src_loc, dst_wh, dst_loc), group|
            itemmovement = Itemmovement.new(
              indate: params[:indate], operator_id: params[:operator_id],
              source_warehouse_id: src_wh, source_location_id: src_loc,
              dest_warehouse_id: dst_wh, dest_location_id: dst_loc
            )

            group.each do |d|
              item = items_by_gencode[d[:gencode]]
              error!("Item #{d[:gencode]} not found", 404) unless item

              sl = StockLevel.find_by(gencode: d[:gencode], warehouse_id: src_wh, location_id: src_loc || 0)
              error!("Insufficient stock for #{d[:gencode]} at WH##{src_wh}/LOC##{src_loc}", 422) unless sl && sl.current_qty >= d[:qty]

              itemmovement.itemmovements_details.build(
                itemcode: d[:gencode], qty: d[:qty], item_id: item.id,
                warehouse_id: src_wh, location_id: src_loc,
                operationtype_id: 2
              )
            end

            ActiveRecord::Base.transaction do
              itemmovement.save!
              CreateInventoriesFromItemmovement.new.call(itemmovement)
            end
          end

          present :success, true
        end

        # GET /api/v1/inventories/stock
        params do
          optional :warehouse_id, type: Integer
          optional :location_id, type: Integer
          optional :gencode, type: String
        end
        get :stock do
          stock = StockLevel.positive.includes(:warehouse, :location)
          stock = stock.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id]
          stock = stock.where(location_id: params[:location_id] || 0) if params[:location_id]
          stock = stock.where(gencode: params[:gencode]) if params[:gencode]

          present stock, with: API::V1::Entities::InventoryDetail
        end
      end
    end
  end
end
```

- [ ] **Step 3: Create entity classes**

```ruby
# app/controllers/api/v1/entities/inventory_detail.rb
module API
  module V1
    module Entities
      class InventoryDetail < Grape::Entity
        expose :gencode
        expose :current_qty
        expose :warehouse_id
        expose :location_id
        expose :warehouse, using: API::V1::Entities::WarehouseSimple, if: { type: :full }
        expose :location, using: API::V1::Entities::LocationSimple, if: { type: :full }
      end

      class WarehouseSimple < Grape::Entity
        expose :id, :code
      end

      class LocationSimple < Grape::Entity
        expose :id, :code
      end
    end
  end
end
```

- [ ] **Step 4: Mount in API::V1::Base**

In `app/controllers/api/v1/base.rb`, add `mount API::V1::Inventories`:

```ruby
# app/controllers/api/v1/base.rb (add this line after other mounts)
mount API::V1::Inventories
```

**No route changes needed** — the existing `mount API::Base, at: "/"` in `routes.rb:83` already handles the path prefix (`/api/v1/inventories/...`). The `resource :inventories` block inside the Grape class routes to `/api/v1/inventories/...` correctly.

- [ ] **Step 5: Add CORS initializer**

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # TODO: restrict to production domain
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

- [ ] **Step 6: Verify API loads**

Run: `bin/rails runner 'puts Rails.application.routes.routes.map(&:path).grep(/api/).join("\n")'`

- [ ] **Step 7: Commit**

```bash
git add Gemfile Gemfile.lock app/controllers/api/v1/inventories.rb app/controllers/api/v1/entities/ app/controllers/api/v1/base.rb config/initializers/cors.rb
git commit -m "feat: add Grape API inventory endpoints for mobile app"
```

---

## Sequencing Summary

| Phase | Tasks | Effort | Risk | Value |
|-------|-------|--------|------|-------|
| **0** | Add gencode columns (Task 0) | Low | Low | Pre-requisite for Phase 2 |
| **1** | StockLevel table + upserts + backfill + query replacement (Tasks 1-5) | High | Medium | **Highest** |
| **2** | Fix N+1, delete dead code (Tasks 6-7) | Low | Low | Medium |
| **3** | MovementBuilder + merge list views (Tasks 8-9) | Medium | Low | Medium |
| **4** | QrParser + rqrcode consolidation (Tasks 10-11) | Low | Low | Low (cleanliness) |
| **5** | Mobile API layer (Task 12) | High | Medium | **Highest** |

## Data Integrity Notes

- `location_id` in StockLevel uses `0` as sentinel for "no location" to satisfy SQLite unique index
- StockLevel upserts are atomic via `Arel.sql` — no race conditions
- All writes happen inside `ActiveRecord::Base.transaction` — rollback is automatic
- Backfill reconciliation step (Task 4 Step 3) verifies StockLevel totals match the event log
- Historical date queries still use the event log (slower but accurate) — StockLevel is for current stock only
- API uses `QrParser` service — single source of truth for QR format parsing

## Bug Fix Log

| Original Bug | Fix Applied | Task |
|-------------|-------------|------|
| **P1** SQLite NULL unique index ambiguous | `location_id` non-null with default 0 | Task 1 |
| **P2** Upsert-then-rollback data inconsistency | Documented transaction dependency; all callers use transactions | Task 2 |
| **P3** View crash: missing @history_by_gencode | Keep history-loading code in both branches of index | Task 5 |
| **P4** View crash: `inv.net_qty` on StockLevel | View uses conditional: `respond_to?(:current_qty)` | Task 5 |
| **P5** Autocomplete silently changes behavior | Documented; StockLevel is more correct for available-stock dropdown | Task 5 |
| **P7** `find_by(gencode:)` needs DB column | Phase 0 adds real gencode columns with backfill | Task 0 |
| **P8** Orphaned `manage_basic_qr_codes` seed | Removed from `db/seeds.rb` line 25 | Task 7 |
| **P9** `movement.details.build` — no association | Uses `DETAIL_ASSOCIATIONS` map with correct names | Task 8 |
| **P10** `ActionController::Parameters` in `header_params` | Uses `.to_unsafe_h` | Task 8 |
| **P12** Missing `operationtype_id` default | `apply_defaults` sets it from `DEFAULT_OPERATION` map | Task 8 |
| **P13** Redirect loses dedicated filtering UX | Documented; `movements` page already has type filter | Task 9 |
| **P14** Menu links break after route removal | Updated menu helper to point to `inventories_movements_path` | Task 9 |
| **P15** Route conflict: doubled path | Mounted inside `API::V1::Base` via `mount`, no `at:` conflict | Task 12 |
| **P16** `rack-cors` not in Gemfile | Added to Gemfile + `bundle install` | Task 12 |
| **P17** API module not mounted in Base | `mount API::V1::Inventories` added to `base.rb` | Task 12 |
| **P21** Transfer groups only by source | Groups by all 4 keys (source + dest) | Task 12 |
| **M1** 5+ redundant `require 'rqrcode'` | Consolidated into `config/initializers/rqrcode.rb` | Task 11 |
| **M5** `AppController#in_warehouse` not in transaction | Wrapped in `ActiveRecord::Base.transaction` | Task 8 |
