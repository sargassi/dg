# Inventory Refactor — Complete Micro-Step Breakdown

**Date:** 2026-06-19  
**Rails:** 7.2.3.1 | **Ruby:** 3.2.2 | **DB:** SQLite | **Test:** Minitest

---

## Pre-Flight Checks (Before ANY changes)

Before we touch a single line, we verify the baseline. These are not optional — if baseline is broken, every subsequent step's "verification" is meaningless.

- [ ] **PF-1: Run full test suite**
  ```bash
  bin/rails test 2>&1 | tail -20
  ```
  **Expected:** All tests pass. If tests fail before we start, document which ones — they're pre-existing failures, not caused by us.

- [ ] **PF-2: Verify DB schema is clean**
  ```bash
  bin/rails db:migrate:status 2>&1 | grep -c "down"
  ```
  **Expected:** `0` (all migrations are "up")

- [ ] **PF-3: Verify all Ruby files parse**
  ```bash
  ruby -c app/models/*.rb && ruby -c app/services/*.rb && ruby -c app/controllers/*.rb 2>&1
  ```
  **Expected:** `Syntax OK` for each file

- [ ] **PF-4: Verify Rails boots**
  ```bash
  bin/rails runner 'puts "Rails booted OK"' 2>&1
  ```
  **Expected:** `Rails booted OK`

- [ ] **PF-5: Note git status baseline**
  ```bash
  git status --short | wc -l
  ```
  **Expected:** `0` (clean working tree — or note any pre-existing dirty files)

---

## Phase 0: Gencode Columns — Enable DB Lookup

### Task 0: Add real gencode columns to warehouses and locations

> **Risk:** LOW. This is a non-destructive addition — new columns only, nothing reads them yet. Backfill is additive.

---

#### Micro-Step 0.1: Write add-column migration

- [ ] Create file `db/migrate/20260619124000_add_gencode_to_warehouses_and_locations.rb` with content:
  ```ruby
  class AddGencodeToWarehousesAndLocations < ActiveRecord::Migration[7.2]
    def change
      add_column :warehouses, :gencode, :string
      add_column :locations,  :gencode, :string
      add_index :warehouses, :gencode
      add_index :locations,  :gencode
    end
  end
  ```
  **Note:** Plan says `Migration[7.0]` but Rails is 7.2 — use `Migration[7.2]`.

- [ ] **Verify:**
  ```bash
  ruby -c db/migrate/20260619124000_add_gencode_to_warehouses_and_locations.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 0.2: Write backfill migration

- [ ] Create file `db/migrate/20260619124100_backfill_warehouse_location_gencode.rb` with content:
  ```ruby
  class BackfillWarehouseLocationGencode < ActiveRecord::Migration[7.2]
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

- [ ] **Verify:**
  ```bash
  ruby -c db/migrate/20260619124100_backfill_warehouse_location_gencode.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 0.3: Run add-column migration

- [ ] **Before:** Record current column count
  ```bash
  bin/rails runner 'puts "Warehouse columns: #{Warehouse.column_names.size}, Location columns: #{Location.column_names.size}"'
  ```
  **Expected:** Some integer values (note them — after migration, each should be +1)

- [ ] Run the migration:
  ```bash
  bin/rails db:migrate
  ```
  **Expected:** Output shows `Migrating to AddGencodeToWarehousesAndLocations`

- [ ] **Verify:**
  ```bash
  bin/rails runner 'puts Warehouse.column_names.include?("gencode") && Location.column_names.include?("gencode") ? "OK: both have gencode" : "FAIL"'
  ```
  **Expected:** `OK: both have gencode`

---

#### Micro-Step 0.4: Run backfill migration

- [ ] Run:
  ```bash
  bin/rails db:migrate
  ```
  **Expected:** Output shows `Migrating to BackfillWarehouseLocationGencode`

- [ ] **Verify backfill populated data:**
  ```bash
  bin/rails runner 'wh = Warehouse.first; loc = Location.first; puts wh ? "WH: id=#{wh.id} code=#{wh.code} gencode=#{wh.gencode}" : "No warehouses"; puts loc ? "LOC: wh_id=#{loc.warehouse_id} id=#{loc.id} code=#{loc.code} gencode=#{loc.gencode}" : "No locations"'
  ```
  **Expected:** Each should show a gencode matching the pattern `<id>_<code>` (warehouse) or `<warehouse_id>_<id>_<code>` (location). NOT nil.

- [ ] **Verify no nils:**
  ```bash
  bin/rails runner 'puts "WH nils: #{Warehouse.where(gencode: nil).count}, LOC nils: #{Location.where(gencode: nil).count}"'
  ```
  **Expected:** `WH nils: 0, LOC nils: 0`

---

#### ⚠️ Micro-Step 0.5: Update Warehouse model to persist gencode on save

> **Risk:** MEDIUM. The `generate_qr_code` callback fires on `after_create_commit`. We must change it to also set `gencode` as a real column. The plan's code uses `self.gencode =` and `update_columns` — note the existing code already uses `update_columns` for `qrcode_svg`. We need to add `gencode` to that same call.

- [ ] **Before:** Verify current `generate_qr_code` method signature and behavior:
  ```bash
  grep -n "def generate_qr_code" app/models/warehouse.rb app/models/location.rb
  ```
  **Expected:** Shows line 11 of warehouse.rb and line 10 of location.rb

- [ ] Edit `app/models/warehouse.rb` — change `generate_qr_code` method:
  **Old (lines 11-13):**
  ```ruby
    def generate_qr_code
      require 'rqrcode'
      update_columns(qrcode_svg: RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end
  ```
  **New:**
  ```ruby
    def generate_qr_code
      require 'rqrcode'
      self.gencode = "#{id}_#{code}"
      update_columns(gencode: self.gencode, qrcode_svg: RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/models/warehouse.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify method is present:**
  ```bash
  grep -c "self.gencode = " app/models/warehouse.rb
  ```
  **Expected:** `1`

---

#### ⚠️ Micro-Step 0.6: Update Location model to persist gencode on save

- [ ] Edit `app/models/location.rb` — change `generate_qr_code` method:
  **Old (lines 10-12):**
  ```ruby
    def generate_qr_code
      require 'rqrcode'
      update_columns(qrcode_svg: RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end
  ```
  **New:**
  ```ruby
    def generate_qr_code
      require 'rqrcode'
      self.gencode = "#{warehouse_id}_#{id}_#{code}"
      update_columns(gencode: self.gencode, qrcode_svg: RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/models/location.rb
  ```
  **Expected:** `Syntax OK`

---

#### ⚠️     : Smoke test — create a new warehouse (verifies callback still works)

- [ ] Create a test warehouse:
  ```bash
  bin/rails runner 'wh = Warehouse.create!(code: "TEST_MS_0_7"); puts "id=#{wh.id}, gencode=#{wh.gencode}, qrcode_present=#{wh.qrcode_svg.present?}"; wh.destroy!'
  ```
  **Expected:** Shows `id=<N>, gencode=<N>_TEST_MS_0_7, qrcode_present=true`, then destroys it cleanly.

---

#### Micro-Step 0.8: Commit Task 0

- [ ] Stage and commit:
  ```bash
  git add db/migrate/20260619124000_add_gencode_to_warehouses_and_locations.rb \
          db/migrate/20260619124100_backfill_warehouse_location_gencode.rb \
          app/models/warehouse.rb app/models/location.rb
  git commit -m "feat: add real gencode columns to warehouses/locations with backfill"
  ```
- [ ] **Verify commit:**
  ```bash
  git log --oneline -1
  ```
  **Expected:** Shows commit with the message above

---

### ▣ CHECKPOINT 0 — Verify Phase 0 Complete

- [ ] **All migrations up:**
  ```bash
  bin/rails db:migrate:status 2>&1 | grep -c "down"
  ```
  **Expected:** `0`

- [ ] **All models parse:**
  ```bash
  ruby -c app/models/warehouse.rb && ruby -c app/models/location.rb && ruby -c app/models/item.rb
  ```
  **Expected:** `Syntax OK` × 3

- [ ] **Gencode columns exist and are populated:**
  ```bash
  bin/rails runner 'puts "WH: #{Warehouse.count} total, #{Warehouse.where(gencode: nil).count} nil"; puts "LOC: #{Location.count} total, #{Location.where(gencode: nil).count} nil"'
  ```
  **Expected:** 0 nil for both

- [ ] **Full test suite:**
  ```bash
  bin/rails test 2>&1 | tail -5
  ```
  **Expected:** Same pass/fail count as PF-1 (no regressions)

- [ ] **Rails boots:**
  ```bash
  bin/rails runner 'puts "Phase 0 complete — Rails booted OK"'
  ```
  **Expected:** `Phase 0 complete — Rails booted OK`

---

## Phase 1: Foundation — Stock Denormalization

### Task 1: Create StockLevel model and migration

---

#### Micro-Step 1.1: Write StockLevel migration

- [ ] Create file `db/migrate/20260619130000_create_stock_levels.rb` with content:
  ```ruby
  class CreateStockLevels < ActiveRecord::Migration[7.2]
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

- [ ] **Verify syntax:**
  ```bash
  ruby -c db/migrate/20260619130000_create_stock_levels.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 1.2: Run StockLevel migration

- [ ] Run:
  ```bash
  bin/rails db:migrate
  ```
  **Expected:** `Migrating to CreateStockLevels`

- [ ] **Verify table exists:**
  ```bash
  bin/rails runner 'puts ActiveRecord::Base.connection.table_exists?("stock_levels") ? "OK: table exists" : "FAIL"'
  ```
  **Expected:** `OK: table exists`

- [ ] **Verify columns:**
  ```bash
  bin/rails runner 'puts ActiveRecord::Base.connection.columns("stock_levels").map(&:name).sort.inspect'
  ```
  **Expected:** `["created_at", "current_qty", "gencode", "id", "location_id", "updated_at", "warehouse_id"]`

- [ ] **Verify unique index:**
  ```bash
  bin/rails runner 'idx = ActiveRecord::Base.connection.indexes("stock_levels").find { |i| i.name == "idx_stock_levels_unique" }; puts idx ? "OK: unique index exists (#{idx.columns.inspect})" : "FAIL: no unique index"'
  ```
  **Expected:** `OK: unique index exists (["gencode", "warehouse_id", "location_id"])`

---

#### Micro-Step 1.3: Create StockLevel model

- [ ] Create file `app/models/stock_level.rb` with content:
  ```ruby
  class StockLevel < ApplicationRecord
    belongs_to :warehouse
    belongs_to :location, optional: true

    scope :positive, -> { where("current_qty > 0") }
  end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/models/stock_level.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify model loads and scopes work:**
  ```bash
  bin/rails runner 'puts "Model: #{StockLevel.name}"; puts "Scope positive responds: #{StockLevel.respond_to?(:positive)}"; puts "Count: #{StockLevel.count}"'
  ```
  **Expected:** `Model: StockLevel`, `Scope positive responds: true`, `Count: 0` (no data yet)

- [ ] **Verify associations:**
  ```bash
  bin/rails runner 'sl = StockLevel.new; puts "responds to warehouse: #{sl.respond_to?(:warehouse)}"; puts "responds to location: #{sl.respond_to?(:location)}"'
  ```
  **Expected:** `responds to warehouse: true`, `responds to location: true`

---

#### Micro-Step 1.4: Create basic StockLevel test file

> **NOTE:** The plan says "Run `bin/rails test test/models/stock_level_test.rb`" but this file doesn't exist. We create a minimal test first.

- [ ] Create file `test/models/stock_level_test.rb` with content:
  ```ruby
  require "test_helper"

  class StockLevelTest < ActiveSupport::TestCase
    test "valid with required fields" do
      sl = StockLevel.new(gencode: "TEST", warehouse_id: 1, current_qty: 10)
      assert sl.valid?
    end

    test "invalid without gencode" do
      sl = StockLevel.new(warehouse_id: 1, current_qty: 10)
      refute sl.valid?
    end

    test "invalid without warehouse_id" do
      sl = StockLevel.new(gencode: "TEST", current_qty: 10)
      refute sl.valid?
    end

    test "default location_id is 0" do
      sl = StockLevel.new(gencode: "TEST", warehouse_id: 1, current_qty: 10)
      assert_equal 0, sl.location_id
    end

    test "default current_qty is 0" do
      sl = StockLevel.new(gencode: "TEST", warehouse_id: 1)
      assert_equal 0, sl.current_qty
    end

    test "positive scope filters zero/negative" do
      StockLevel.create!(gencode: "POS", warehouse_id: 1, current_qty: 5)
      StockLevel.create!(gencode: "ZERO", warehouse_id: 1, current_qty: 0)
      StockLevel.create!(gencode: "NEG", warehouse_id: 1, current_qty: -3)
      assert_equal 1, StockLevel.positive.count
    end
  end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c test/models/stock_level_test.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Run the test:**
  ```bash
  bin/rails test test/models/stock_level_test.rb
  ```
  **Expected:** 6 tests, 0 failures, 0 errors

---

#### Micro-Step 1.5: Commit Task 1

- [ ] Stage and commit:
  ```bash
  git add db/migrate/20260619130000_create_stock_levels.rb \
          app/models/stock_level.rb \
          test/models/stock_level_test.rb
  git commit -m "feat: add StockLevel model for denormalized current stock"
  ```
- [ ] **Verify:**
  ```bash
  git log --oneline -1
  ```
  **Expected:** Shows the commit

---

### Task 2: Add StockLevel upserts to all Inventory creation services

> **⚠️ RISK: MEDIUM.** These services are called in production flows. Wrong upsert logic = wrong stock counts. Verify the Arel.sql expressions carefully.

---

#### ⚠️ Micro-Step 2.1: Add upsert to CreateInventoriesFromItemin

- [ ] **Before:** Record current file state for rollback reference:
  ```bash
  wc -l app/services/create_inventories_from_itemin.rb
  ```
  **Expected:** `30` (current line count)

- [ ] Edit `app/services/create_inventories_from_itemin.rb` — add upsert after `Inventory.create!`:

  **Replace the whole file** with:
  ```ruby
  class CreateInventoriesFromItemin
    require 'rqrcode'

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

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/services/create_inventories_from_itemin.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify StockLevel.upsert is present (grep check):**
  ```bash
  grep -c "StockLevel.upsert" app/services/create_inventories_from_itemin.rb
  ```
  **Expected:** `1`

---

#### ⚠️ Micro-Step 2.2: Add upsert to CreateInventoriesFromItemout

- [ ] **Replace the whole file** `app/services/create_inventories_from_itemout.rb` with:
  ```ruby
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

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/services/create_inventories_from_itemout.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify upsert uses subtraction (not addition):**
  ```bash
  grep "COALESCE" app/services/create_inventories_from_itemout.rb
  ```
  **Expected:** Shows `COALESCE(current_qty, 0) - #{detail.qty.to_i}` (minus sign)

---

#### ⚠️ Micro-Step 2.3: Add upserts to CreateInventoriesFromItemmovement

- [ ] **Replace the whole file** `app/services/create_inventories_from_itemmovement.rb` with:
  ```ruby
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

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/services/create_inventories_from_itemmovement.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify BOTH upserts exist (source subtract, dest add):**
  ```bash
  grep -c "StockLevel.upsert" app/services/create_inventories_from_itemmovement.rb
  ```
  **Expected:** `2`

---

#### Micro-Step 2.4: Verify all three services parse

- [ ] Run:
  ```bash
  ruby -c app/services/create_inventories_from_itemin.rb && \
  ruby -c app/services/create_inventories_from_itemout.rb && \
  ruby -c app/services/create_inventories_from_itemmovement.rb
  ```
  **Expected:** `Syntax OK` × 3

---

#### Micro-Step 2.5: Commit Task 2

- [ ] Stage and commit:
  ```bash
  git add app/services/create_inventories_from_itemin.rb \
          app/services/create_inventories_from_itemout.rb \
          app/services/create_inventories_from_itemmovement.rb
  git commit -m "feat: add StockLevel upserts to all inventory creation services"
  ```
- [ ] **Verify:**
  ```bash
  git log --oneline -1
  ```

---

### Task 3: Update ImportInventoryService to use standard services

> **⚠️ RISK: MEDIUM.** This is the biggest single-file refactor. The old code created Inventory records directly; the new code delegates, which also triggers StockLevel upserts. The entire block runs inside the existing `ActiveRecord::Base.transaction`.

---

#### ⚠️ Micro-Step 3.1: Replace `save` method in ImportInventoryService

- [ ] **Before:** Record line count for comparison:
  ```bash
  wc -l app/services/import_inventory_service.rb
  ```
  **Expected:** `129` (current)

- [ ] Replace lines 50-128 (the entire `save` method) in `app/services/import_inventory_service.rb` with the new implementation. The `parse` and `validate_row` methods (lines 1-48) stay unchanged.

  **New `save` method (replace lines 50-128):**
  ```ruby
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

  > **Note on the edit:** We're replacing lines 50-128. The `end` on line 129 closes the class — it stays.

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/services/import_inventory_service.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify old code is GONE (these patterns should NOT exist):**
  ```bash
  grep -c "minstock" app/services/import_inventory_service.rb
  ```
  **Expected:** `0`

  ```bash
  grep -c "maxstock" app/services/import_inventory_service.rb
  ```
  **Expected:** `0`

- [ ] **Verify delegation calls exist:**
  ```bash
  grep -c "CreateInventoriesFromItemin.new.call" app/services/import_inventory_service.rb
  ```
  **Expected:** `1`

  ```bash
  grep -c "CreateInventoriesFromItemout.new.call" app/services/import_inventory_service.rb
  ```
  **Expected:** `1`

---

#### Micro-Step 3.2: Run the existing inventory test to catch regressions

- [ ] Run:
  ```bash
  bin/rails test test/models/inventory_test.rb 2>&1 | tail -10
  ```
  **Expected:** All tests pass (document any pre-existing failures)

---

#### Micro-Step 3.3: Commit Task 3

- [ ] Stage and commit:
  ```bash
  git add app/services/import_inventory_service.rb
  git commit -m "refactor: ImportInventoryService delegates to standard services"
  ```

---

### Task 4: Backfill existing stock levels

> **⚠️ RISK: HIGH.** This migration computes stock from all historical inventory records. If the SUM logic is wrong, stock counts are wrong. The reconciliation step (4.3) is the most critical verification in the entire plan.

---

#### Micro-Step 4.1: Write backfill migration

- [ ] Create file `db/migrate/20260619140000_backfill_stock_levels.rb` with content:
  ```ruby
  class BackfillStockLevels < ActiveRecord::Migration[7.2]
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

- [ ] **Verify syntax:**
  ```bash
  ruby -c db/migrate/20260619140000_backfill_stock_levels.rb
  ```
  **Expected:** `Syntax OK`

---

#### ⚠️ Micro-Step 4.2: Run backfill migration

- [ ] **Before:** Check StockLevel is empty:
  ```bash
  bin/rails runner 'puts "StockLevel count before: #{StockLevel.count}"'
  ```
  **Expected:** `StockLevel count before: 0`

- [ ] Run:
  ```bash
  bin/rails db:migrate
  ```
  **Expected:** `Migrating to BackfillStockLevels`

- [ ] **After:** Check rows were created:
  ```bash
  bin/rails runner 'puts "StockLevel count after: #{StockLevel.count}"; puts "Positive rows: #{StockLevel.positive.count}"'
  ```
  **Expected:** Non-zero counts (values depend on your data)

---

#### ⚠️🔴 Micro-Step 4.3: CRITICAL — Reconciliation check

> **If this fails, DO NOT proceed.** StockLevel data is corrupted and must be investigated.

- [ ] Run reconciliation:
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
  **Expected:** `[OK] Reconciled: StockLevel total <N> matches Inventory log total <N>`

---

#### Micro-Step 4.4: Commit Task 4

- [ ] Stage and commit:
  ```bash
  git add db/migrate/20260619140000_backfill_stock_levels.rb
  git commit -m "feat: backfill StockLevel from existing Inventory records"
  ```

---

### Task 5: Replace SUM queries with StockLevel reads

> **⚠️ RISK: HIGH.** This changes the main inventory query path. The view uses `inv.net_qty` which StockLevel objects don't have (`current_qty` instead). Must also handle the conditional where historical date queries still use `net_qty`.

---

#### ⚠️ Micro-Step 5.1: Replace index query in InventoriesController

- [ ] **Before:** Record line count:
  ```bash
  wc -l app/controllers/inventories_controller.rb
  ```
  **Expected:** `501`

- [ ] Replace lines 6-75 (the `index` method) in `app/controllers/inventories_controller.rb` with the new dual-branch implementation that uses StockLevel for current-date queries but keeps event-log for historical dates. Also keep the history-loading code.

  **The change is:**
  - Wrap the old `base`/`@inventories` query block (lines 17-44) in an `if @date != Date.current` branch
  - Add an `else` branch that uses `StockLevel.positive` for current-date
  - Keep lines 46-74 (history loading) as-is at the end

  Instead of me writing the entire method here (the plan already has it at lines 526-617), the edit strategy is:

  1. Replace line 17-44 block (from `base = Inventory.where...` through `@pagy, @inventories = pagy...`) with the conditional branches.
  2. Keep lines 46-74 intact.

  Let me be precise about the edit ranges:

  **Old lines 17-44 (to be replaced):**
  ```ruby
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
  
      @inventories = base
        .group(:gencode)
        .select(
          :gencode,
          Arel.sql("MAX(inventories.itemcode) AS itemcode"),
          Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END) - SUM(CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
        ).order(:gencode)
  
      if params[:q].present?
        q = "%#{params[:q]}%"
        @inventories = @inventories.having("inventories.gencode LIKE :q", q: q)
      end
  
      count = base.distinct.count(:gencode)
      @pagy, @inventories = pagy(@inventories, count: count)
  ```

  **New replacement:**
  ```ruby
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
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/inventories_controller.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify StockLevel reference exists in controller:**
  ```bash
  grep -c "StockLevel.positive" app/controllers/inventories_controller.rb
  ```
  **Expected:** `1`

- [ ] **Verify old `base = Inventory.where...` is GONE (except in historical branch):**
  ```bash
  grep -c "base = Inventory.where" app/controllers/inventories_controller.rb
  ```
  **Expected:** `1` (only in the historical branch)

---

#### ⚠️ Micro-Step 5.2: Fix view — `net_qty` → `current_qty`

- [ ] **Before:** Check the current line 72:
  ```bash
  sed -n '72p' app/views/inventories/index.html.erb
  ```
  **Expected:** `<td class="<%= style_table_td %> font-mono font-bold text-lg..."><%= inv.net_qty %></td>`

- [ ] Edit `app/views/inventories/index.html.erb` line 72:
  
  **Old:**
  ```erb
                  <td class="<%= style_table_td %> font-mono font-bold text-lg <%= inv.net_qty.to_i >= 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400' %>"><%= inv.net_qty %></td>
  ```
  
  **New:**
  ```erb
                  <td class="<%= style_table_td %> font-mono font-bold text-lg <%= inv.respond_to?(:current_qty) ? (inv.current_qty >= 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400') : (inv.net_qty.to_i >= 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400') %>"><%= inv.respond_to?(:current_qty) ? inv.current_qty : inv.net_qty.to_i %></td>
  ```

- [ ] **Verify change is present:**
  ```bash
  grep -c "current_qty" app/views/inventories/index.html.erb
  ```
  **Expected:** `4` (two for display, two for color conditional)

- [ ] **Verify `net_qty` fallback still present:**
  ```bash
  grep -c "net_qty" app/views/inventories/index.html.erb
  ```
  **Expected:** `2` (the fallback references)

---

#### ⚠️ Micro-Step 5.3: Replace autocomplete SUM query in InventoriesController

- [ ] Replace lines 104-110 in `app/controllers/inventories_controller.rb`:
  
  **Old:**
  ```ruby
      net_qty_by_key = Inventory.where(gencode: inventories.map(&:gencode).uniq)
        .group(:gencode, :warehouse_id, :location_id)
        .select(
          :gencode, :warehouse_id, :location_id,
          Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END) - SUM(CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
        )
        .each_with_object({}) { |row, h| h[[row.gencode, row.warehouse_id, row.location_id]] = row.net_qty }
  ```
  
  **New:**
  ```ruby
      stock_levels = StockLevel.where(gencode: inventories.map(&:gencode).uniq)
      net_qty_by_key = stock_levels.each_with_object({}) { |sl, h|
        h[[sl.gencode, sl.warehouse_id, sl.location_id]] = sl.current_qty
      }
  ```

- [ ] **Verify change:**
  ```bash
  grep -c "StockLevel.where(gencode:" app/controllers/inventories_controller.rb
  ```
  **Expected:** `1`

---

#### ⚠️ Micro-Step 5.4: Replace lookup_by_qr legacy SUM query in InventoriesController

- [ ] Replace lines 460-465 (inside `legacy_qr_result` method) in `app/controllers/inventories_controller.rb`:
  
  **Old:**
  ```ruby
        positions = Inventory.where(item_id: item.id)
          .group(:warehouse_id, :location_id)
          .select(
            :warehouse_id, :location_id,
            Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END) - SUM(CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
          )
          .having("net_qty > 0")
  ```
  
  **New:**
  ```ruby
        positions = StockLevel.where(gencode: item.gencode).positive.includes(:warehouse, :location)
  ```

- [ ] **Also update the map block** (lines 469-478) to use `current_qty`:
  
  **Old:**
  ```ruby
          positions: positions.map { |p|
            {
              warehouse_id: p.warehouse_id,
              location_id: p.location_id,
              warehouse: p.warehouse&.code,
              location: p.location&.code,
              net_qty: p.net_qty
            }
          }
  ```
  
  **New:**
  ```ruby
          positions: positions.map { |sl|
            {
              warehouse_id: sl.warehouse_id,
              location_id: sl.location_id,
              warehouse: sl.warehouse&.code,
              location: sl.location&.code,
              net_qty: sl.current_qty
            }
          }
  ```

- [ ] **Verify:**
  ```bash
  grep -c "StockLevel.where(gencode:" app/controllers/inventories_controller.rb
  ```
  **Expected:** `2` (one from autocomplete, one from lookup_by_qr)

---

#### ⚠️ Micro-Step 5.5: Replace itemouts_controller bulk SUM

- [ ] Replace lines 114-120 in `app/controllers/itemouts_controller.rb`:
  
  **Old:**
  ```ruby
        net_qty_by_key = Inventory.where(gencode: gencodes)
          .group(:gencode, :warehouse_id, :location_id)
          .select(
            :gencode, :warehouse_id, :location_id,
            Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END) - SUM(CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
          )
          .each_with_object({}) { |row, h| h[[row.gencode, row.warehouse_id, row.location_id]] = row.net_qty }
  ```
  
  **New:**
  ```ruby
        stock = StockLevel.where(gencode: gencodes)
          .each_with_object({}) { |sl, h| h[[sl.gencode, sl.warehouse_id, sl.location_id]] = sl.current_qty }
  ```
  
  **Also update the reference** — the variable name changed from `net_qty_by_key` to `stock`. The usage on line 127 references `net_qty_by_key`:
  
  **Old (line 127):**
  ```ruby
          available = net_qty_by_key[[item.gencode, d[:warehouse_id].to_i, d[:location_id].to_i]] || 0
  ```
  
  **New:**
  ```ruby
          available = stock[[item.gencode, d[:warehouse_id].to_i, d[:location_id].to_i]] || 0
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/itemouts_controller.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify variable name updated:**
  ```bash
  grep -c "net_qty_by_key" app/controllers/itemouts_controller.rb
  ```
  **Expected:** `0`

- [ ] **Verify new variable:**
  ```bash
  grep -c "stock\[\[" app/controllers/itemouts_controller.rb
  ```
  **Expected:** `1`

---

#### Micro-Step 5.6: Full syntax check of all touched files

- [ ] Run:
  ```bash
  ruby -c app/controllers/inventories_controller.rb && \
  ruby -c app/controllers/itemouts_controller.rb && \
  ruby -c app/views/inventories/index.html.erb 2>&1
  ```
  **Expected:** `Syntax OK` × 3

---

#### Micro-Step 5.7: Commit Task 5

- [ ] Stage and commit:
  ```bash
  git add app/controllers/inventories_controller.rb \
          app/controllers/itemouts_controller.rb \
          app/views/inventories/index.html.erb
  git commit -m "perf: replace SUM queries with StockLevel reads, keep history loading"
  ```

---

### ▣ CHECKPOINT 1 — Verify Phase 1 Complete

- [ ] **All migrations up:**
  ```bash
  bin/rails db:migrate:status 2>&1 | grep -c "down"
  ```
  **Expected:** `0`

- [ ] **All Ruby files parse:**
  ```bash
  ruby -c app/models/*.rb && ruby -c app/services/*.rb && ruby -c app/controllers/*.rb 2>&1 | grep -v "Syntax OK"
  ```
  **Expected:** No output (all files parse OK)

- [ ] **StockLevel model exists and has data:**
  ```bash
  bin/rails runner 'puts "StockLevel rows: #{StockLevel.count}, positive: #{StockLevel.positive.count}"'
  ```
  **Expected:** Non-zero counts

- [ ] **Reconciliation still passes:**
  ```bash
  bin/rails runner '
  el = Inventory.select(Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable,0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable,0) ELSE 0 END) AS gt")).to_a.first.gt.to_i
  st = StockLevel.sum(:current_qty)
  puts el == st ? "[OK] #{el} == #{st}" : "[FAIL] #{st} != #{el}"
  '
  ```
  **Expected:** `[OK] <N> == <N>`

- [ ] **Full test suite:**
  ```bash
  bin/rails test 2>&1 | tail -5
  ```
  **Expected:** Compare pass/fail with PF-1 — no new failures

- [ ] **Rails boots:**
  ```bash
  bin/rails runner 'puts "Phase 1 complete"'
  ```
  **Expected:** `Phase 1 complete`

---

## Phase 2: Fix N+1s and Dead Code

### Task 6: Fix warehouses_controller lookup_by_qr N+1

---

#### Micro-Step 6.1: Replace Ruby iteration with DB queries

- [ ] **Before:** Verify current code pattern:
  ```bash
  grep -c "Warehouse.all.each" app/controllers/warehouses_controller.rb
  ```
  **Expected:** `1`

- [ ] Replace lines 19-42 in `app/controllers/warehouses_controller.rb`:
  
  **Old:**
  ```ruby
    def lookup_by_qr
      q = params[:q].to_s.strip
      result = { warehouse_id: nil, warehouse_code: nil, location_id: nil, location_code: nil }
  
      Warehouse.all.each do |wh|
        if wh.gencode == q
          result[:warehouse_id] = wh.id
          result[:warehouse_code] = wh.code
          break
        end
      end
  
      Location.all.each do |loc|
        if loc.gencode == q
          result[:location_id] = loc.id
          result[:location_code] = loc.code
          result[:warehouse_id] ||= loc.warehouse_id
          result[:warehouse_code] ||= loc.warehouse&.code
          break
        end
      end
  
      render json: result
    end
  ```
  
  **New:**
  ```ruby
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

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/warehouses_controller.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify old each loops are GONE:**
  ```bash
  grep -c "Warehouse.all.each" app/controllers/warehouses_controller.rb
  ```
  **Expected:** `0`

- [ ] **Verify new find_by uses gencode column:**
  ```bash
  grep -c "find_by(gencode:" app/controllers/warehouses_controller.rb
  ```
  **Expected:** `2`

- [ ] **Verify method is still defined:**
  ```bash
  bin/rails runner 'puts WarehousesController.instance_methods.include?(:lookup_by_qr) ? "OK: method exists" : "FAIL"'
  ```

---

#### Micro-Step 6.2: Commit Task 6

- [ ] Stage and commit:
  ```bash
  git add app/controllers/warehouses_controller.rb
  git commit -m "perf: fix warehouses lookup_by_qr N+1, use direct DB queries on gencode column"
  ```

---

### Task 7: Delete dead code

---

#### Micro-Step 7.1: Remove dead service file

- [ ] **Before:** Verify file exists:
  ```bash
  test -f app/services/check_qr_code_service.rb && echo "EXISTS" || echo "MISSING"
  ```
  **Expected:** `EXISTS`

- [ ] Remove:
  ```bash
  git rm app/services/check_qr_code_service.rb
  ```

- [ ] **Verify:**
  ```bash
  test -f app/services/check_qr_code_service.rb && echo "STILL EXISTS" || echo "GONE"
  ```
  **Expected:** `GONE`

---

#### Micro-Step 7.2: Remove dead controller file

- [ ] **Before:** Verify file exists:
  ```bash
  test -f app/controllers/basic_qr_codes_controller.rb && echo "EXISTS" || echo "MISSING"
  ```
  **Expected:** `EXISTS`

- [ ] Remove:
  ```bash
  git rm app/controllers/basic_qr_codes_controller.rb
  ```

- [ ] **Verify:**
  ```bash
  test -f app/controllers/basic_qr_codes_controller.rb && echo "STILL EXISTS" || echo "GONE"
  ```
  **Expected:** `GONE`

---

#### Micro-Step 7.3: Remove dead routes from config/routes.rb

- [ ] **Before:** Verify the lines exist:
  ```bash
  grep -n "basic-qr-code-reader\|basic_qr_codes/qrcheck" config/routes.rb
  ```
  **Expected:** Shows lines 179 and 180

- [ ] Delete lines 179-180 from `config/routes.rb`:
  
  **Delete these two lines:**
  ```ruby
    get 'basic-qr-code-reader', to: 'basic_qr_codes#index'
    get 'basic_qr_codes/qrcheck'
  ```

- [ ] **Verify they're gone:**
  ```bash
  grep -c "basic_qr_codes" config/routes.rb
  ```
  **Expected:** `0`

- [ ] **Verify routes file parses:**
  ```bash
  bin/rails runner 'puts Rails.application.routes.routes.size'
  ```
  **Expected:** A number (routes still load)

---

#### Micro-Step 7.4: Remove orphaned seed entry

- [ ] **Before:** Verify the seed line exists:
  ```bash
  grep -n "manage_basic_qr_codes" db/seeds.rb
  ```
  **Expected:** Shows line 25

- [ ] Delete line 25 from `db/seeds.rb`:
  
  **Delete this line:**
  ```ruby
    { name: 'manage_basic_qr_codes', description: 'Lettore QR code base',                            category: 'Utilities' },
  ```

- [ ] **Verify it's gone:**
  ```bash
  grep -c "manage_basic_qr_codes" db/seeds.rb
  ```
  **Expected:** `0`

---

#### Micro-Step 7.5: Verify nothing references deleted files

- [ ] Check for lingering references:
  ```bash
  rg "check_qr_code_service|basic_qr_codes" --type ruby app/ config/ lib/ 2>&1 | grep -v "Binary\|No files"
  ```
  **Expected:** No output (no references remain)

- [ ] **Verify Rails boots:**
  ```bash
  bin/rails runner 'puts "Boot OK"'
  ```
  **Expected:** `Boot OK`

---

#### Micro-Step 7.6: Commit Task 7

- [ ] Stage and commit:
  ```bash
  git add config/routes.rb db/seeds.rb
  git commit -m "chore: remove dead code (check_qr_code_service, basic_qr_codes_controller) and orphaned seed"
  ```

---

### ▣ CHECKPOINT 2 — Verify Phase 2 Complete

- [ ] **Full test suite:**
  ```bash
  bin/rails test 2>&1 | tail -5
  ```
  **Expected:** Same pass/fail as PF-1 (no regressions)

- [ ] **Rails routes load:**
  ```bash
  bin/rails runner 'puts Rails.application.routes.routes.size'
  ```
  **Expected:** A number (routes load without error)

- [ ] **Dead code truly gone:**
  ```bash
  test -f app/services/check_qr_code_service.rb || test -f app/controllers/basic_qr_codes_controller.rb && echo "STILL EXISTS" || echo "All dead files removed"
  ```
  **Expected:** `All dead files removed`

- [ ] **All Ruby files parse:**
  ```bash
  ruby -c app/**/*.rb 2>&1 | grep -v "Syntax OK"
  ```
  **Expected:** No output

- [ ] **Rails boots:**
  ```bash
  bin/rails runner 'puts "Phase 2 complete"'
  ```

---

## Phase 3: DRY Up Controllers

### Task 8: Extract MovementBuilder service

---

#### Micro-Step 8.1: Create MovementBuilder service

- [ ] Create file `app/services/movement_builder.rb` with content:
  ```ruby
  class MovementBuilder
    DETAIL_ASSOCIATIONS = {
      Itemin        => :itemins_details,
      Itemout       => :itemouts_details,
      Itemmovement  => :itemmovements_details
    }.freeze

    DEFAULT_OPERATION = {
      Itemin        => 1,
      Itemout       => 2,
      Itemmovement  => nil
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

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/services/movement_builder.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify constants and public API:**
  ```bash
  bin/rails runner '
  puts MovementBuilder::DETAIL_ASSOCIATIONS.keys.inspect
  puts MovementBuilder.new(Itemin, {}).respond_to?(:build) ? "OK: responds to build" : "FAIL"
  '
  ```
  **Expected:** `[Itemin, Itemout, Itemmovement]` and `OK: responds to build`

---

#### ⚠️ Micro-Step 8.2: Replace `in_warehouse` POST block in AppController

- [ ] **Before:** Record the current `in_warehouse` POST block (lines 64-82):
  ```bash
  grep -n "if request.post?" app/controllers/app_controller.rb
  ```
  **Expected:** `64` (line 64)

- [ ] Replace the POST handling in `in_warehouse` (lines 64-82):
  
  **Old (lines 64-82):**
  ```ruby
      if request.post?
        p = in_warehouse_params
        default_collection_id = params[:default_collection_id]
        default_warehouse_id = params[:default_warehouse_id]
        default_location_id = params[:default_location_id]
  
        attrs = p.to_h
        (attrs[:itemins_details_attributes] || {}).each do |key, detail|
          detail["collection_id"] = default_collection_id if detail["collection_id"].blank? && default_collection_id.present?
          detail["warehouse_id"] = default_warehouse_id if detail["warehouse_id"].blank? && default_warehouse_id.present?
          detail["location_id"] = default_location_id if detail["location_id"].blank? && default_location_id.present?
        end
        attrs[:itemins_details_attributes]&.reject! { |_, d|
          d["_destroy"] == "1" || (d["itemcode"].blank? && d["item_id"].blank?)
        }
        @itemin = Itemin.new(attrs)
  
        if @itemin.save
          CreateInventoriesFromItemin.new.call(@itemin)
          redirect_to app_in_warehouse_confirmation_path(itemin_id: @itemin.id, from_seleziona: params[:from_seleziona])
        else
          ...
        end
      end
  ```
  
  **New:**
  ```ruby
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
      end
  ```

  > **Note:** The `else` branch (handling save failure) can be simplified — if `save!` raises inside the transaction, it propagates to the caller. We need a `rescue` block. The plan says to wrap in `ActiveRecord::Base.transaction`. The existing `rescue` should catch `ActiveRecord::RecordInvalid`. Keep the existing `else` branch for the GET case.

  Actually, looking more carefully at the old code, the `else` on line 84-91 handles a failed `@itemin.save` (returns false, re-renders with errors). In the new code, we use `save!` (raises). We must add `rescue`:

  **Full replacement for the POST branch (keeping the rescue):**
  ```ruby
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
      rescue ActiveRecord::RecordInvalid => e
        @from_seleziona = params[:from_seleziona] == "1"
        @default_collection_id = params[:default_collection_id]
        @default_warehouse_id = params[:default_warehouse_id]
        @default_location_id = params[:default_location_id]
        load_form_data
        flash.now[:alert] = @itemin.errors.full_messages.to_sentence
        render :in_warehouse, status: :unprocessable_entity
      else
        ... (GET branch unchanged)
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/app_controller.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify MovementBuilder usage:**
  ```bash
  grep -c "MovementBuilder.new" app/controllers/app_controller.rb
  ```
  **Expected:** `1` (after this step)

---

#### ⚠️ Micro-Step 8.3: Replace `out_warehouse` POST block in AppController

- [ ] Replace the POST handling in `out_warehouse` (lines 124-152):
  
  **Old (lines 124-140 + save logic):**
  ```ruby
      if request.post?
        p = out_warehouse_params
        @itemout = Itemout.new(indate: p[:indate], notes: p[:notes], operator_id: p[:operator_id])
        default_collection_id = params[:default_collection_id]
        default_warehouse_id = params[:default_warehouse_id]
        default_location_id = params[:default_location_id]
        details = (p[:itemouts_details_attributes]&.values || [])
          .reject { |d| d[:_destroy] == "1" }
          .reject { |d| d[:itemcode].blank? && d[:item_id].blank? }
          .map { |d|
            d = d.except(:_destroy)
            d[:collection_id] = default_collection_id if d[:collection_id].blank? && default_collection_id.present?
            d[:warehouse_id] = default_warehouse_id if d[:warehouse_id].blank? && default_warehouse_id.present?
            d[:location_id] = default_location_id if d[:location_id].blank? && default_location_id.present?
            d
          }
        @itemout.itemouts_details.build(details)
  
        if @itemout.save
          CreateInventoriesFromItemout.new.call(@itemout)
          redirect_to app_out_warehouse_confirmation_path(itemout_id: @itemout.id)
        else
          ...
        end
  ```
  
  **New:**
  ```ruby
      if request.post?
        @itemout = MovementBuilder.new(
          Itemout, params[:itemout],
          defaults: {
            collection_id: params[:default_collection_id],
            warehouse_id: params[:default_warehouse_id],
            location_id: params[:default_location_id]
          }
        ).build
  
        ActiveRecord::Base.transaction do
          @itemout.save!
          CreateInventoriesFromItemout.new.call(@itemout)
        end
  
        redirect_to app_out_warehouse_confirmation_path(itemout_id: @itemout.id)
      rescue ActiveRecord::RecordInvalid => e
        @default_collection_id = params[:default_collection_id]
        @default_warehouse_id = params[:default_warehouse_id]
        @default_location_id = params[:default_location_id]
        load_form_data
        flash.now[:alert] = @itemout.errors.full_messages.to_sentence
        render :out_warehouse, status: :unprocessable_entity
      else
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/app_controller.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify MovementBuilder count:**
  ```bash
  grep -c "MovementBuilder.new" app/controllers/app_controller.rb
  ```
  **Expected:** `2`

---

#### ⚠️ Micro-Step 8.4: Replace `move_products` POST block in AppController

- [ ] Replace the POST handling in `move_products` (lines 165-205):

  This one is more complex because it groups by `[warehouse_id, location_id]` and creates one `Itemmovement` per group. The MovementBuilder handles detail building but not grouping logic. We use MovementBuilder for each group.

  **Old POST block (lines 165-205):**
  ```ruby
      if request.post?
        p = move_products_params
        @created_ids = []
        errors = []
  
        details = (p[:itemmovements_details_attributes]&.values || [])
          .reject { |d| d[:_destroy] == "1" }
          .reject { |d| d[:itemcode].blank? && d[:item_id].blank? }
          .reject { |d| d[:warehouse_id].blank? }
          .map { |d| d.except(:_destroy) }
  
        if params[:dest_warehouse_id].blank?
          ...error...
        end
  
        if details.empty?
          ...error...
        end
  
        grouped = details.group_by { |d| [d[:warehouse_id], d[:location_id]] }
  
        Itemmovement.transaction do
          grouped.each do |(wh_id, loc_id), group_details|
            movement = Itemmovement.new(
              indate: p[:indate], notes: p[:notes], operator_id: p[:operator_id],
              source_warehouse_id: wh_id, source_location_id: loc_id,
              dest_warehouse_id: params[:dest_warehouse_id],
              dest_location_id: params[:dest_location_id]
            )
            movement.itemmovements_details.build(group_details)
            movement.save!
            CreateInventoriesFromItemmovement.new.call(movement)
            @created_ids << movement.id
          end
        end
  
        redirect_to app_move_products_confirmation_path(ids: @created_ids.join(","))
  ```

  **New — keeps grouping logic, uses MovementBuilder for detail processing:**
  ```ruby
      if request.post?
        @created_ids = []
  
        builder = MovementBuilder.new(
          Itemmovement, params[:itemmovement],
          defaults: {}
        )
        details = builder.send(:build_details)
  
        if details.empty?
          @movement = Itemmovement.new(indate: params[:itemmovement][:indate])
          load_form_data(ordered: true)
          flash.now[:alert] = "Nessun articolo valido. Compila il codice articolo selezionando dall'autocomplete."
          render :move_products, status: :unprocessable_entity and return
        end
  
        if params[:dest_warehouse_id].blank?
          @movement = Itemmovement.new(indate: params[:itemmovement][:indate])
          load_form_data(ordered: true)
          flash.now[:alert] = "Seleziona un magazzino di destinazione."
          render :move_products, status: :unprocessable_entity and return
        end
  
        p = params[:itemmovement].to_unsafe_h
        grouped = details.group_by { |d| [d[:warehouse_id], d[:location_id]] }
  
        ActiveRecord::Base.transaction do
          grouped.each do |(wh_id, loc_id), group_details|
            movement = Itemmovement.new(
              indate: p["indate"], notes: p["notes"], operator_id: p["operator_id"],
              source_warehouse_id: wh_id, source_location_id: loc_id,
              dest_warehouse_id: params[:dest_warehouse_id],
              dest_location_id: params[:dest_location_id]
            )
            movement.itemmovements_details.build(group_details)
            movement.save!
            CreateInventoriesFromItemmovement.new.call(movement)
            @created_ids << movement.id
          end
        end
  
        redirect_to app_move_products_confirmation_path(ids: @created_ids.join(","))
      rescue ActiveRecord::RecordInvalid => e
        @movement = Itemmovement.new(indate: p["indate"], dest_warehouse_id: params[:dest_warehouse_id], dest_location_id: params[:dest_location_id])
        @default_dest_warehouse_id = params[:dest_warehouse_id]
        @default_dest_location_id = params[:dest_location_id]
        load_form_data(ordered: true)
        flash.now[:alert] = e.record.errors.full_messages.to_sentence
        render :move_products, status: :unprocessable_entity
      else
  ```

  > **Important:** Using `.send(:build_details)` to access the private method is a bit ugly. An alternative: expose `build_details` as public. But the plan's approach uses MovementBuilder for detail building only; the grouping and movement creation remains in the controller. Let me adjust to make `build_details` a public method on MovementBuilder... Actually, the plan doesn't mention this. Let me just inline the detail processing here since the grouping logic is unique to `move_products`. The key DRY improvement is removing the manual `.reject/.map` blocks — MovementBuilder handles those.

  Actually, let me provide a cleaner approach: add a `details` public method to MovementBuilder that returns the processed details array, then use it in `move_products`. Let me update the MovementBuilder to add this:

  Wait, I shouldn't change the plan. The plan's MovementBuilder doesn't have this. Let me keep the approach simple: inline a simpler detail extraction in `move_products` that doesn't duplicate the full rejection logic. But the plan says to use MovementBuilder...

  Let me just go with a practical approach — extract the `build_details` logic into a simple helper that `move_products` calls. Actually, the simplest correct approach: make `build_details` public in MovementBuilder (rename or add an alias). Let me adjust the service slightly:

  Actually, let me not over-complicate this. The plan's MovementBuilder is designed for the `in_warehouse`/`out_warehouse`/`itemins_controller` pattern where you call `.build` and get back a movement object. For `move_products`, the grouping is different enough that it's fine to have a small amount of detail-processing code stay in the controller. The key win is removing the copy-pasted logic from the other 2 methods.

  Let me simplify: for `move_products`, don't use MovementBuilder at all (the grouping logic is unique). Just clean up the detail processing by extracting a simple method. But the plan says to use MovementBuilder...

  OK, I'll stick close to the plan. The plan says to replace with MovementBuilder but doesn't specify exactly how for `move_products`. Let me provide a pragmatic version that uses MovementBuilder to build an Itemmovement but the controller handles grouping:

  **Simpler approach for move_products — use MovementBuilder for detail sanitization only.**

  Add a public method to MovementBuilder:
  ```ruby
  def details
    build_details
  end
  ```

  Then in the controller:
  ```ruby
  builder = MovementBuilder.new(Itemmovement, params[:itemmovement])
  details = builder.details
  # ... grouping and movement creation as before
  ```

  This keeps the detail-rejection logic in ONE place (MovementBuilder) while keeping the grouping logic in the controller where it belongs.

  Let me update the MovementBuilder file to add this public method. Actually, I'll just do this as a separate micro-step.

  For now, let me simplify: **don't change `move_products` to use MovementBuilder** — it's the most complex method and the plan's MovementBuilder wasn't designed for the grouping pattern. Instead, just clean it up later. Focus on `in_warehouse` and `out_warehouse` which are the primary DRY targets.

  Actually, re-reading the plan: "Same pattern for `out_warehouse` (with `Itemout` and `CreateInventoriesFromItemout`) and `move_products` (with `Itemmovement` and `CreateInventoriesFromItemmovement`). Remove all manual `.reject/.map` blocks."

  The plan clearly expects MovementBuilder to be used for `move_products` too. Let me just do a clean implementation.

  **Strategy:** Add a public `sanitized_details` method to MovementBuilder, use it in `move_products`:

  I'll add to the MovementBuilder:
  ```ruby
  def sanitized_details
    build_details
  end
  ```

  OK, I'm going to stop overthinking. Let me provide the micro-steps that work and explain the tradeoffs. For `move_products`, I'll show using MovementBuilder's internal `build_details` via a public wrapper.

---

Let me restart this section cleanly with practical micro-steps:

#### Micro-Step 8.2 (Revised): Replace `in_warehouse` POST in AppController

- [ ] Replace the POST branch (lines 65-82) with MovementBuilder + transaction wrapper

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/app_controller.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 8.3 (Revised): Replace `out_warehouse` POST in AppController

- [ ] Replace the POST branch (lines 124-152) with MovementBuilder + transaction wrapper

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/app_controller.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 8.4: Add `sanitized_details` public method to MovementBuilder

- [ ] Add this method to `app/services/movement_builder.rb` (after the `build` method):
  ```ruby
    def sanitized_details
      build_details
    end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/services/movement_builder.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 8.5: Replace `move_products` detail processing in AppController

- [ ] In `move_products`, replace the manual `.reject/.map` block with `MovementBuilder.new(...).sanitized_details`, while keeping the grouping and movement creation logic.

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/app_controller.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 8.6: Replace in IteminsController#confirm

- [ ] Replace lines 70-87 in `app/controllers/itemins_controller.rb`:
  
  **Old:**
  ```ruby
      @itemin = Itemin.new(@params.except(:itemins_details_attributes))
  
      details = (@params[:itemins_details_attributes] || {}).values
        .reject { |d| d["_destroy"] == "1" }
        .map { |d| d.slice("itemcode", "qty", "item_id", "collection_id", "warehouse_id", "location_id", "operationtype_id") }
      @itemin.itemins_details.build(details)
  
      begin
        ActiveRecord::Base.transaction do
          @itemin.save!
          CreateInventoriesFromItemin.new.call(@itemin)
        end
  
        session.delete(:itemin_preview)
        redirect_to inventories_dashboard_path, notice: "Carico creato con #{@itemin.itemins_details.size} articoli"
      rescue => e
        redirect_to new_itemin_path, alert: "Errore durante il salvataggio: #{e.message}"
      end
  ```
  
  **New:**
  ```ruby
      @itemin = MovementBuilder.new(Itemin, @params).build
  
      begin
        ActiveRecord::Base.transaction do
          @itemin.save!
          CreateInventoriesFromItemin.new.call(@itemin)
        end
  
        session.delete(:itemin_preview)
        redirect_to inventories_dashboard_path, notice: "Carico creato con #{@itemin.itemins_details.size} articoli"
      rescue => e
        redirect_to new_itemin_path, alert: "Errore durante il salvataggio: #{e.message}"
      end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/itemins_controller.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify MovementBuilder usage in IteminsController:**
  ```bash
  grep -c "MovementBuilder" app/controllers/itemins_controller.rb
  ```
  **Expected:** `1`

---

#### Micro-Step 8.7: Full syntax check

- [ ] Run:
  ```bash
  ruby -c app/services/movement_builder.rb && \
  ruby -c app/controllers/app_controller.rb && \
  ruby -c app/controllers/itemins_controller.rb
  ```
  **Expected:** `Syntax OK` × 3

---

#### Micro-Step 8.8: Commit Task 8

- [ ] Stage and commit:
  ```bash
  git add app/services/movement_builder.rb \
          app/controllers/app_controller.rb \
          app/controllers/itemins_controller.rb
  git commit -m "refactor: extract MovementBuilder service with correct association handling"
  ```

---

### Task 9: Merge triplicate list views + fix menu links

---

#### Micro-Step 9.1: Replace list methods with redirects in AppController

- [ ] Replace `itemins_list` method (lines 227-262) in `app/controllers/app_controller.rb`:
  
  **Old (entire method body):**
  ```ruby
    def itemins_list
      @itemins = Itemin.includes(:operator, itemins_details: [:warehouse, :location, :item])
        .order(indate: :desc)
      @operators = User.joins(:itemins).distinct.order(:name)
      @warehouses = Warehouse.order(:code)
      @locations = Location.order(:code)
      ...
      @pagy, @itemins = pagy(@itemins)
    end
  ```
  
  **New:**
  ```ruby
    def itemins_list
      redirect_to inventories_movements_path(operationtype_id: 1)
    end
  ```

- [ ] Same for `itemouts_list` (lines 264-299):
  
  **New:**
  ```ruby
    def itemouts_list
      redirect_to inventories_movements_path(operationtype_id: 2)
    end
  ```

- [ ] Same for `itemmovements_list` (lines 301-334):
  
  **New:**
  ```ruby
    def itemmovements_list
      redirect_to inventories_movements_path(operationtype_id: 3)
    end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/app_controller.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 9.2: Update menu helper in AppController

- [ ] Replace lines 349-351 in `app/controllers/app_controller.rb`:
  
  **Old:**
  ```ruby
        { label: 'Carichi', path: app_itemins_list_path, icon: 'list_alt', active: active == 'itemins_list', can: 'manage_app_sectors' },
        { label: 'Scarichi', path: app_itemouts_list_path, icon: 'list_alt', active: active == 'itemouts_list', can: 'manage_app_sectors' },
        { label: 'Variazioni', path: app_itemmovements_list_path, icon: 'swap_vert', active: active == 'itemmovements_list', can: 'manage_app_sectors' },
  ```
  
  **New:**
  ```ruby
        { label: 'Carichi', path: inventories_movements_path(operationtype_id: 1), icon: 'list_alt', active: active == 'itemins_list', can: 'manage_app_sectors' },
        { label: 'Scarichi', path: inventories_movements_path(operationtype_id: 2), icon: 'list_alt', active: active == 'itemouts_list', can: 'manage_app_sectors' },
        { label: 'Variazioni', path: inventories_movements_path(operationtype_id: 3), icon: 'swap_vert', active: active == 'itemmovements_list', can: 'manage_app_sectors' },
  ```

- [ ] **Verify change:**
  ```bash
  grep -c "app_itemins_list_path" app/controllers/app_controller.rb
  ```
  **Expected:** `0`

---

#### Micro-Step 9.3: Remove old view files

- [ ] Remove all three list view files:
  ```bash
  git rm app/views/app/itemins_list.html.erb \
         app/views/app/itemouts_list.html.erb \
         app/views/app/itemmovements_list.html.erb
  ```

- [ ] **Verify they're gone:**
  ```bash
  test -f app/views/app/itemins_list.html.erb || test -f app/views/app/itemouts_list.html.erb || test -f app/views/app/itemmovements_list.html.erb && echo "STILL EXISTS" || echo "All removed"
  ```
  **Expected:** `All removed`

---

#### Micro-Step 9.4: Verify route helpers still resolve

- [ ] Run:
  ```bash
  bin/rails runner '
  puts Rails.application.routes.url_helpers.respond_to?(:app_itemins_list_path) ? "routes still registered" : "routes removed"
  '
  ```
  **Expected:** `routes still registered` (routes weren't deleted, just the views)

- [ ] **Verify Rails boots:**
  ```bash
  bin/rails runner 'puts "Boot OK"'
  ```
  **Expected:** `Boot OK`

---

#### Micro-Step 9.5: Commit Task 9

- [ ] Stage and commit:
  ```bash
  git add app/controllers/app_controller.rb
  git commit -m "refactor: redirect triplicate list views to InventoriesController#movements"
  ```

---

### ▣ CHECKPOINT 3 — Verify Phase 3 Complete

- [ ] **All Ruby files parse:**
  ```bash
  ruby -c app/services/*.rb && ruby -c app/controllers/*.rb 2>&1 | grep -v "Syntax OK"
  ```
  **Expected:** No output

- [ ] **Full test suite:**
  ```bash
  bin/rails test 2>&1 | tail -5
  ```
  **Expected:** Same pass/fail as PF-1

- [ ] **Rails boots:**
  ```bash
  bin/rails runner 'puts "Phase 3 complete"'
  ```

---

## Phase 4: Extract Shared QR Parser + Consolidate requires

### Task 10: Extract QR parsing to shared service

---

#### Micro-Step 10.1: Create QrParser service

- [ ] Create file `app/services/qr_parser.rb` with content:
  ```ruby
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

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/services/qr_parser.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify parse works correctly:**
  ```bash
  bin/rails runner '
  r1 = QrParser.parse("AAA_BBB_1_2_42")
  r2 = QrParser.parse("AAA_BBB_1")
  r3 = QrParser.parse("simple_gencode")
  puts "With detail: #{r1.inspect}"
  puts "No detail (underscore): #{r2.inspect}"
  puts "No detail (plain): #{r3.inspect}"
  '
  ```
  **Expected:**
  - `With detail: {:gencode=>"AAA_BBB_1_2", :detail_id=>42}`
  - `No detail (underscore): {:gencode=>"AAA_BBB_1", :detail_id=>nil}`
  - `No detail (plain): {:gencode=>"simple_gencode", :detail_id=>nil}`

---

#### Micro-Step 10.2: Replace `extract_gencode_and_detail_id` in InventoriesController

- [ ] Replace lines 449-457 in `app/controllers/inventories_controller.rb`:
  
  **Old:**
  ```ruby
      def extract_gencode_and_detail_id(text)
        if text =~ /\A(.+)_(\d+)\z/
          candidate_gencode = $1
          candidate_detail_id = $2.to_i
          if candidate_gencode =~ /_(\d+)\z/
            [candidate_gencode, candidate_detail_id]
          end
        end
      end
  ```
  
  **New:**
  ```ruby
      def extract_gencode_and_detail_id(text)
        parsed = QrParser.parse(text)
        parsed[:detail_id] ? [parsed[:gencode], parsed[:detail_id]] : nil
      end
  ```

  > **Alternative:** Just delete `extract_gencode_and_detail_id` and update `parse_qr_code` to use `QrParser` directly. Let me do the cleaner version.

  Actually, `parse_qr_code` method (lines 413-447) calls `extract_gencode_and_detail_id` on line 414. Let me refactor `parse_qr_code` to use `QrParser` directly and delete the old `extract_gencode_and_detail_id` method entirely.

  **New `parse_qr_code` method:**
  ```ruby
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

  **Delete `extract_gencode_and_detail_id` method entirely (lines 449-457).**

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/inventories_controller.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify old method is GONE:**
  ```bash
  grep -c "def extract_gencode_and_detail_id" app/controllers/inventories_controller.rb
  ```
  **Expected:** `0`

- [ ] **Verify QrParser is used:**
  ```bash
  grep -c "QrParser" app/controllers/inventories_controller.rb
  ```
  **Expected:** `1`

---

#### Micro-Step 10.3: Replace `parse_qr_gencode` in MainwareController

- [ ] Replace lines 212-221 in `app/controllers/mainware_controller.rb`:
  
  **Old:**
  ```ruby
    def parse_qr_gencode(text)
      if text =~ /\A(.+)_(\d+)\z/
        candidate_gencode = $1
        candidate_detail_id = $2.to_i
        if candidate_gencode =~ /_(\d+)\z/
          return candidate_gencode
        end
      end
      text
    end
  ```
  
  **New:**
  ```ruby
    def parse_qr_gencode(text)
      QrParser.parse(text)[:gencode]
    end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/mainware_controller.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 10.4: Commit Task 10

- [ ] Stage and commit:
  ```bash
  git add app/services/qr_parser.rb \
          app/controllers/inventories_controller.rb \
          app/controllers/mainware_controller.rb
  git commit -m "refactor: extract QrParser service, remove duplicate QR parsing logic"
  ```

---

### Task 11: Consolidate require 'rqrcode'

---

#### Micro-Step 11.1: Create rqrcode initializer

- [ ] Create file `config/initializers/rqrcode.rb` with content:
  ```ruby
  require 'rqrcode'
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c config/initializers/rqrcode.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 11.2: Remove inline `require 'rqrcode'` from Item model

- [ ] Remove line 24 from `app/models/item.rb` (`require 'rqrcode'`)

- [ ] **Verify it's gone:**
  ```bash
  grep -c "require 'rqrcode'" app/models/item.rb
  ```
  **Expected:** `0`

---

#### Micro-Step 11.3: Remove inline `require 'rqrcode'` from Warehouse model

- [ ] Remove line 12 from `app/models/warehouse.rb`

- [ ] **Verify it's gone:**
  ```bash
  grep -c "require 'rqrcode'" app/models/warehouse.rb
  ```
  **Expected:** `0`

---

#### Micro-Step 11.4: Remove inline `require 'rqrcode'` from Location model

- [ ] Remove line 11 from `app/models/location.rb`

- [ ] **Verify it's gone:**
  ```bash
  grep -c "require 'rqrcode'" app/models/location.rb
  ```
  **Expected:** `0`

---

#### Micro-Step 11.5: Remove inline `require 'rqrcode'` from CreateInventoriesFromItemin

- [ ] Remove line 2 from `app/services/create_inventories_from_itemin.rb`

- [ ] **Verify it's gone:**
  ```bash
  grep -c "require 'rqrcode'" app/services/create_inventories_from_itemin.rb
  ```
  **Expected:** `0`

---

#### Micro-Step 11.6: Verify CreateQrService still has its require (intentionally kept)

- [ ] Verify:
  ```bash
  grep -c "require 'rqrcode'" app/services/create_qr_service.rb
  ```
  **Expected:** `1` (this one stays — standalone service, harmless)

---

#### Micro-Step 11.7: Verify all models and services still parse

- [ ] Run:
  ```bash
  ruby -c app/models/item.rb && \
  ruby -c app/models/warehouse.rb && \
  ruby -c app/models/location.rb && \
  ruby -c app/services/create_inventories_from_itemin.rb
  ```
  **Expected:** `Syntax OK` × 4

---

#### Micro-Step 11.8: Commit Task 11

- [ ] Stage and commit:
  ```bash
  git add config/initializers/rqrcode.rb \
          app/models/item.rb \
          app/models/warehouse.rb \
          app/models/location.rb \
          app/services/create_inventories_from_itemin.rb
  git commit -m "chore: consolidate require 'rqrcode' into initializer"
  ```

---

### ▣ CHECKPOINT 4 — Verify Phase 4 Complete

- [ ] **Rails boots with initializer:**
  ```bash
  bin/rails runner 'puts "Phase 4 boot OK"'
  ```
  **Expected:** `Phase 4 boot OK`

- [ ] **QR code generation still works:**
  ```bash
  bin/rails runner 'puts Item.first.qrcode_svg.present? ? "QR OK" : "QR FAIL"'
  ```

- [ ] **Full test suite:**
  ```bash
  bin/rails test 2>&1 | tail -5
  ```

- [ ] **All Ruby files parse:**
  ```bash
  ruby -c app/**/*.rb config/initializers/rqrcode.rb 2>&1 | grep -v "Syntax OK"
  ```
  **Expected:** No output

---

## Phase 5: Mobile API Layer

### Task 12: Build Grape API inventory endpoints

---

#### Micro-Step 12.1: Add rack-cors to Gemfile

- [ ] Add to `Gemfile`:
  ```ruby
  gem 'rack-cors'
  ```
  
  Add it after the existing `grape` gems.

- [ ] Install:
  ```bash
  bundle install
  ```

- [ ] **Verify gem is installed:**
  ```bash
  bundle info rack-cors 2>&1 | head -3
  ```
  **Expected:** Shows version info (not "not found")

---

#### Micro-Step 12.2: Create CORS initializer

- [ ] Create file `config/initializers/cors.rb` with content:
  ```ruby
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins '*'
      resource '*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head]
    end
  end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c config/initializers/cors.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 12.3: Create API entity classes

- [ ] Create file `app/controllers/api/v1/entities/inventory_detail.rb` with content:
  ```ruby
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

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/api/v1/entities/inventory_detail.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify entities load:**
  ```bash
  bin/rails runner 'puts API::V1::Entities::InventoryDetail.name'
  ```
  **Expected:** `API::V1::Entities::InventoryDetail`

---

#### Micro-Step 12.4: Create API inventories endpoint

- [ ] Create file `app/controllers/api/v1/inventories.rb` with the full content from the plan (lines 1097-1282). This is a large file with 4 endpoints: `GET lookup`, `POST inbound`, `POST outbound`, `POST transfer`, `GET stock`.

  > Due to file size, copy the code from the plan lines 1097-1282.

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/api/v1/inventories.rb
  ```
  **Expected:** `Syntax OK`

- [ ] **Verify class loads:**
  ```bash
  bin/rails runner 'puts API::V1::Inventories.name'
  ```
  **Expected:** `API::V1::Inventories`

---

#### Micro-Step 12.5: Mount in API::V1::Base

- [ ] Add `mount API::V1::Inventories` to `app/controllers/api/v1/base.rb`:
  
  **Old:**
  ```ruby
  module API
    module V1
      class Base < Grape::API
        mount API::V1::Prows
        mount API::V1::Tempestas
      end
    end
  end
  ```
  
  **New:**
  ```ruby
  module API
    module V1
      class Base < Grape::API
        mount API::V1::Prows
        mount API::V1::Tempestas
        mount API::V1::Inventories
      end
    end
  end
  ```

- [ ] **Verify syntax:**
  ```bash
  ruby -c app/controllers/api/v1/base.rb
  ```
  **Expected:** `Syntax OK`

---

#### Micro-Step 12.6: Verify API routes load

- [ ] Run:
  ```bash
  bin/rails runner 'routes = Rails.application.routes.routes.map { |r| r.path.spec.to_s }; puts routes.select { |p| p.include?("api/v1/inventories") }.sort.join("\n")'
  ```
  **Expected:** Shows paths like `/api/v1/inventories/lookup`, `/api/v1/inventories/stock`, etc.

---

#### Micro-Step 12.7: Smoke test an API endpoint (if server available)

- [ ] Start server briefly and test, OR just verify route registration:
  ```bash
  bin/rails runner '
  routes = Rails.application.routes.routes.map { |r| r.path.spec.to_s }
  api_routes = routes.select { |p| p.include?("api/v1/inventories") }
  puts api_routes.any? ? "OK: #{api_routes.size} API inventory routes" : "FAIL: no routes"
  '
  ```
  **Expected:** `OK: <N> API inventory routes` (where N ≥ 4)

---

#### Micro-Step 12.8: Commit Task 12

- [ ] Stage and commit:
  ```bash
  git add Gemfile Gemfile.lock \
          app/controllers/api/v1/inventories.rb \
          app/controllers/api/v1/entities/inventory_detail.rb \
          app/controllers/api/v1/base.rb \
          config/initializers/cors.rb
  git commit -m "feat: add Grape API inventory endpoints for mobile app"
  ```

---

### ▣ CHECKPOINT 5 — FINAL — Verify Everything

- [ ] **All migrations up:**
  ```bash
  bin/rails db:migrate:status 2>&1 | grep -c "down"
  ```
  **Expected:** `0`

- [ ] **All Ruby files parse (entire app):**
  ```bash
  ruby -c app/**/*.rb config/initializers/*.rb 2>&1 | grep -v "Syntax OK"
  ```
  **Expected:** No output

- [ ] **Full test suite:**
  ```bash
  bin/rails test 2>&1
  ```
  **Expected:** Compare with PF-1. Document any new failures.

- [ ] **Reconciliation final check:**
  ```bash
  bin/rails runner '
  el = Inventory.select(Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable,0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable,0) ELSE 0 END) AS gt")).to_a.first.gt.to_i
  st = StockLevel.sum(:current_qty)
  puts el == st ? "[OK] Final reconciliation: #{el} == #{st}" : "[FAIL] #{st} != #{el}"
  '
  ```
  **Expected:** `[OK] Final reconciliation: <N> == <N>`

- [ ] **API routes registered:**
  ```bash
  bin/rails runner 'puts Rails.application.routes.routes.select { |r| r.path.spec.to_s.include?("api/v1/inventories") }.map { |r| "#{r.verb} #{r.path.spec}" }.join("\n")'
  ```
  **Expected:** Shows GET/POST API inventory routes

- [ ] **Rails boots clean:**
  ```bash
  bin/rails runner 'puts "🎉 Inventory refactor complete — Rails booted OK"'
  ```

- [ ] **Git log summary:**
  ```bash
  git log --oneline | head -15
  ```
  **Expected:** Shows all 12+ commits

---

## Summary Statistics

| Phase | Tasks | Micro-Steps | Deletions | Adds | Risk |
|-------|-------|-------------|-----------|------|------|
| PF   | Pre-flight | 5 | 0 | 0 | — |
| 0    | Task 0 | 8 | 0 | 6 files | Low |
| 1    | Tasks 1-5 | 25 | SUM queries | StockLevel, upserts | High |
| 2    | Tasks 6-7 | 6 | 3 files | 1 | Low |
| 3    | Tasks 8-9 | 13 | ~80 LOC | MovementBuilder | Medium |
| 4    | Tasks 10-11 | 12 | ~4 requires | QrParser, initializer | Low |
| 5    | Task 12 | 8 | 0 | API + CORS | Medium |

**Total: ~77 micro-steps across 12 tasks + 5 checkpoints + 5 pre-flight checks**

---

## ⚠️ High-Risk Micro-Steps Summary

| Step | Risk | Why |
|------|------|-----|
| **4.2** | HIGH | Backfill migration — computes stock from all history. Wrong = bad data. |
| **4.3** | CRITICAL | Reconciliation check. If this fails, STOP. Do not proceed. |
| **5.1** | HIGH | Changes main inventory query path. Broke view = blank page. |
| **5.2** | HIGH | View change. `net_qty`→`current_qty`. Wrong = crash or wrong numbers. |
| **8.2-8.5** | MEDIUM | Replaces real user-facing controller logic. If MovementBuilder fails, users can't create inbound/outbound operations. |

---

Ready to execute. Say `@odb go ahead` and I'll start with Pre-Flight Check PF-1.
