# Rails 8.x / Ruby 3.4+ Upgrade Strategy

> **Current:** Rails 7.2.3.1 / Ruby 3.2.2  
> **Target:** Rails 8.x / Ruby 3.4+  
> **Assessment:** Requires ~30 fixes across 8 categories. Not safe to bump-and-ship.

---

## Overview

| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Gems | 6 | 0 | 7 | 4 |
| Rails APIs | 0 | 3 | 3 | 2 |
| Ruby 3.4 | 1 | 0 | 1 | 1 |
| SQLite | 1 | 0 | 3 | 2 |
| Views | 1 | 13 `form_for` | 1 | 1 |
| Routes | 0 | 0 | 0 | 1 |
| Grape API | 1 | 1 | 1 | 1 |
| Other | 1 | 0 | 3 | 3 |

---

## Phase 1: Critical Blockers (Remove Pre-Upgrade Obstacles)

These prevent `bundle update rails` from even completing or crash the app on boot.

### 1.1 Unpin `rack` 2.x lock

**File:** `Gemfile`

**Problem:** `gem "rack", "~> 2.2.18"` pins Rack 2.x. Rails 8 requires Rack 3.x.

**Fix:**
```ruby
# Change:
gem "rack", "~> 2.2.18"
# To:
gem "rack", "~> 3.0"
```

### 1.2 Remove `byebug` (duplicate debugger)

**File:** `Gemfile:112`

**Problem:** `byebug` 13.0.0 cannot compile on Ruby 3.3+. Already have `debug` gem in the same Gemfile.

**Fix:** Delete line 112:
```ruby
# DELETE this line:
gem "byebug", "13.0.0"
```

### 1.3 Fix foreign key referencing non-existent table

**File:** `db/schema.rb:583`

**Problem:** `add_foreign_key "prodrow", "prodcodes"` — table `prodcodes` does not exist. The actual table is `products`. `db:schema:load` will fail under Rails 8 strict FK validation.

**Fix:** Create a migration to fix the FK:
```ruby
# db/migrate/20260619150000_fix_prodrow_foreign_key.rb
class FixProdrowForeignKey < ActiveRecord::Migration[7.0]
  def up
    remove_foreign_key :prodrow, :prodcodes, if_exists: true
    add_foreign_key :prodrow, :products, column: :prodcode_id
  end

  def down
    remove_foreign_key :prodrow, :products
    # Don't add back the bad FK
  end
end
```

### 1.4 Replace `form_tag` (removed in Rails 8)

**File:** `app/views/inventories/seleziona.html.erb:123`

**Problem:** `form_tag` is deprecated since Rails 5.1 and removed in Rails 8.

**Fix:** Replace with `form_with`:
```erb
<!-- OLD -->
<%= form_tag inventories_prepare_carico_path, method: :post do %>

<!-- NEW -->
<%= form_with url: inventories_prepare_carico_path, method: :post do |f| %>
```

### 1.5 Replace `WickedPdf.config =` with block syntax

**File:** `config/initializers/wicked_pdf.rb:11, 34`

**Problem:** `WickedPdf.config = {...}` is deprecated. Already showing warnings in test output.

**Fix:**
```ruby
# OLD:
WickedPdf.config = {
  exe_path: ...
}

# NEW:
WickedPdf.configure do |config|
  config.exe_path = ...
end
```

### 1.6 Remove `byebug` + `debug` conflict

Already covered in 1.2. After deletion, run:
```bash
bundle install
```

### Phase 1 Commit

```bash
git add Gemfile Gemfile.lock config/initializers/wicked_pdf.rb app/views/inventories/seleziona.html.erb db/migrate/*_fix_prodrow_foreign_key.rb
git commit -m "chore: fix critical blockers for Rails 8 upgrade (rack pin, byebug, form_tag, FK, wicked_pdf)"
```

---

## Phase 2: Migrate `form_for` → `form_with` (13 files)

All `form_for` must become `form_with`. Rails 8 may hard-break on `form_for`.

### 2.1 Regenerate Devise views

**Files:** `app/views/devise/**/*.erb`

After upgrading Devise and Rails, regenerate views:
```bash
rails generate devise:views
```

This replaces 7 Devise view files automatically with `form_with` syntax.

### 2.2 Fix remaining app views

**Files:**
- `app/views/products_imports/new.html.erb:3`
- `app/views/atoms/_form_import.html.erb:4`

**Pattern:** Replace `form_for @object do |f|` with `form_with model: @object do |f|`.

```erb
<!-- OLD -->
<%= form_for @product_import do |f| %>
  ...
<% end %>

<!-- NEW -->
<%= form_with model: @product_import do |f| %>
  ...
<% end %>
```

### 2.3 Ransack forms — no change needed

`search_form_for` in Ransack views (`rassegnas/index.html.erb`, `atoms/_search_qr.html.erb`, `atoms/_search_single.html.erb`, `production/research.html.erb`) is a Ransack helper, not `form_for`. No change needed.

### Phase 2 Commit

```bash
git add app/views/devise/ app/views/products_imports/ app/views/atoms/_form_import.html.erb
git commit -m "chore: migrate form_for to form_with for Rails 8 compatibility"
```

---

## Phase 3: Bump Rails Defaults (Incremental)

### 3.1 Bump to Rails 7.1 defaults

**File:** `config/application.rb:12`

```ruby
# Change:
config.load_defaults 7.0
# To:
config.load_defaults 7.1
```

Run tests, fix deprecation warnings:
```bash
bin/rails test 2>&1 | grep DEPRECATION
```

Key 7.1 changes to watch for:
- `config.active_record.encryption.support_unencrypted_data` — deprecated
- `config.active_storage.multiple_file_upload` — new default
- `config.action_dispatch.show_exceptions` — new default for API-only

### 3.2 Remove `support_unencrypted_data` escape hatch

**File:** `config/application.rb:14`

```ruby
# DELETE this line (deprecated in 7.1, removed in 8.0):
config.active_record.encryption.support_unencrypted_data = true
```

Before removing, verify no encrypted columns exist with legacy data. If any exist, decrypt and re-encrypt them first.

### 3.3 Bump to Rails 7.2 defaults

```ruby
config.load_defaults 7.2
```

Run tests again. Fix new deprecations.

### 3.4 Bump to Rails 8.0

```ruby
config.load_defaults 8.0
```

Rails 8 defaults to:
- Propshaft (not Sprockets) — verify `tailwindcss-rails` integration
- `solid_cache` (DB-backed cache) — replaces `file_store`
- `solid_queue` (DB-backed jobs) — replaces Sidekiq/Resque
- Kamal (deployment) — replaces Capistrano if desired

### Phase 3 Commit

```bash
git add config/application.rb
git commit -m "chore: bump config.load_defaults to 8.0, remove support_unencrypted_data"
```

---

## Phase 4: Gem Version Bumps

### 4.1 Critical bumps (required)

| Gem | From | To |
|-----|------|-----|
| `rack` | `~> 2.2.18` | `~> 3.0` |
| `puma` | `~> 5.6` | `~> 6.0` |
| `redis` | `~> 4.0` | `~> 5.0` |
| `pagy` | `~> 7.0` | `~> 9.0` |

### 4.2 Remove abandonware

| Gem | Reason |
|-----|--------|
| `byebug` | Removed in Phase 1 |
| `rabl` | Third JSON approach. Kill it. Use `jbuilder` + `grape-entity`. |
| `carrierwave` | Already have Active Storage. Remove `carrierwave` from Gemfile. |

### 4.3 Test thoroughly after bumps

```bash
bundle update rack puma redis pagy
bin/rails test
bin/rails server -p 3000  # smoke test
```

### 4.4 Verify ransack compatibility

Ransack 4.4.1 → latest 4.x. Bump and run all search-heavy pages:
```bash
bundle update ransack
bin/rails test
```

### Phase 4 Commit

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: bump gems for Rails 8 compatibility, remove byebug/rabl/carrierwave"
```

---

## Phase 5: Grape API Modernization

### 5.1 Migrate from `active_model_serializers` to `grape-entity`

**Problem:** `grape-active_model_serializers` 2.0.1 is abandonware. AMS 0.10.x unmaintained since 2020.

**Files:**
- `app/controllers/api/v1/defaults.rb:12`
- `app/controllers/api/v1/tempestas.rb`
- `app/controllers/api/v1/prows.rb`

**Step 1: Add grape-entity**

```ruby
# Gemfile
gem "grape-entity", "~> 1.0"
```

**Step 2: Replace formatter**

```ruby
# app/controllers/api/v1/defaults.rb
# OLD:
formatter :json, Grape::Formatter::ActiveModelSerializers

# NEW:
formatter :json, Grape::Formatter::Json
```

**Step 3: Define entities for Tempesta and Prow**

```ruby
# app/controllers/api/v1/entities/tempesta_entity.rb
module API::V1::Entities
  class TempestaEntity < Grape::Entity
    expose :id, :qrcode, :prow_id, :created_at
  end
end
```

**Step 4: Update API endpoints**

Replace `present @tempestas` with `present @tempestas, with: API::V1::Entities::TempestaEntity`.

### 5.2 Fix SQL injection risk in Tempestas API

**File:** `app/controllers/api/v1/tempestas.rb:18-26`

**Problem:** `Tempesta.where('f1 is null and ...')` uses string column name from `case params[:station]`. Safe currently but fragile.

**Fix:** Use symbol key with `#{}`:
```ruby
station_col = ALLOWED_STATIONS.include?(params[:station]) ? params[:station].to_sym : nil
error!('Invalid station', 400) unless station_col

Tempesta.where(station_col => nil, prow_id: params[:prow_id], qrcode: params[:qrcode])
```

### 5.3 Add pagination to Prows API

**File:** `app/controllers/api/v1/prows.rb:8`

**Problem:** `Prow.all` returns the entire table.

```ruby
# Use pagy (already a dependency)
pagy, prows = pagy(Prow.all, page: params[:page] || 1)
present prows, with: ProwEntity
# Include pagination metadata in response
header 'X-Total', pagy.count.to_s
header 'X-Page', pagy.page.to_s
```

### Phase 5 Commit

```bash
git add Gemfile Gemfile.lock app/controllers/api/v1/
git commit -m "refactor: migrate Grape API from AMS to grape-entity, add pagination"
```

---

## Phase 6: SQLite & Data Integrity

### 6.1 Fix `prodrow` foreign key

Already done in Phase 1.3.

### 6.2 Add missing foreign keys

**New migration:**

```ruby
# db/migrate/20260619151000_add_missing_foreign_keys.rb
class AddMissingForeignKeys < ActiveRecord::Migration[7.0]
  def change
    add_foreign_key :itemins_details, :collections, if_not_exists: true
    add_foreign_key :itemins_details, :warehouses, if_not_exists: true
    add_foreign_key :itemins_details, :locations, if_not_exists: true

    add_foreign_key :itemouts_details, :collections, if_not_exists: true
    add_foreign_key :itemouts_details, :warehouses, if_not_exists: true
    add_foreign_key :itemouts_details, :locations, if_not_exists: true

    add_foreign_key :itemmovements_details, :collections, if_not_exists: true
    add_foreign_key :itemmovements_details, :warehouses, if_not_exists: true
    add_foreign_key :itemmovements_details, :locations, if_not_exists: true
  end
end
```

### 6.3 Verify SQLite version after upgrade

```bash
sqlite3 --version
# Should be >= 3.40 for Rails 8 compatibility
```

### 6.4 Enable foreign key enforcement

**File:** `config/database.yml` (if missing, check if `PRAGMA foreign_keys = ON` is set)

Rails 8 may enforce foreign keys by default. Verify with:
```bash
bin/rails runner 'puts ActiveRecord::Base.connection.execute("PRAGMA foreign_keys").first'
```

### Phase 6 Commit

```bash
git add db/migrate/*_add_missing_foreign_keys.rb
git commit -m "chore: add missing foreign key constraints for data integrity"
```

---

## Phase 7: View & Asset Cleanup

### 7.1 Migrate to Propshaft (optional — keep Sprockets if needed)

Rails 8 defaults to Propshaft. `tailwindcss-rails` v3.x works with both.

**If keeping Sprockets:**
- No changes needed for `stylesheet_link_tag`
- Add `config.assets.legacy_manifest = true` to `application.rb` if needed

**If migrating to Propshaft:**
- Replace `sprockets-rails` with `propshaft` in Gemfile
- Update `wicked_pdf_stylesheet_link_tag` to `wicked_pdf_asset_path` in `app/views/layouts/pdf.html.erb:9`
- Tailwind CSS output moves from `app/assets/stylesheets` to `app/assets/builds`
- Run `bin/rails tailwindcss:build` before deployment

### 7.2 Clean up `application.html.erb`

**File:** `app/views/layouts/application.html.erb`

Verify `stylesheet_link_tag` still works with chosen asset pipeline. No changes if keeping Sprockets.

### 7.3 Remove `style_main_*` helper if Sprockets goes away

The codebase uses custom style helpers like `style_main_header_container`, `style_search_input`, `style_table_th`. These are unaffected by asset pipeline changes — they're Ruby helpers, not asset-related.

### Phase 7 Commit

```bash
# Only if migrating to Propshaft:
git add Gemfile Gemfile.lock app/views/layouts/pdf.html.erb app/assets/builds/
git commit -m "refactor: migrate from Sprockets to Propshaft for Rails 8"
```

---

## Phase 8: Remove Dead Code & Models

### 8.1 Fix orphaned `belongs_to :account`

**File:** `app/models/rassegna.rb:3`

```ruby
# DELETE this line (or define Account model):
belongs_to :account, :optional => true
```

### 8.2 Fix `Productrow` belongs_to

**File:** `app/models/productrow.rb:2`

```ruby
# Already references Product, but FK in schema is wrong.
# Phase 1.3 fix handles the FK. Model is fine.
belongs_to :product
```

### 8.3 Move business logic out of ApplicationController

**File:** `app/controllers/application_controller.rb:26-48`

`hasDoneTempestas?` and `setProwDone` are business logic in the base controller. They should be in `app/models/prow.rb`:

```ruby
# app/models/prow.rb (add these methods)
def done?
  done
end

def mark_done!
  update!(done: true)
end
```

Then replace in ApplicationController:
```ruby
# OLD:
hasDoneTempestas?(@prow)  # in application_controller
setProwDone(@prow)        # in application_controller

# NEW:
@prow.done?               # on the model
@prow.mark_done!          # on the model
```

### Phase 8 Commit

```bash
git add app/models/rassegna.rb app/models/prow.rb app/controllers/application_controller.rb
git commit -m "refactor: clean up dead associations and move business logic to models"
```

---

## Phase 9: Date.parse Hardening

Ruby 3.4 is stricter with malformed date strings. The `rescue nil` pattern works but silently swallows errors.

**Files (6 locations):**
- `app/controllers/inventories_controller.rb:9,199,205`
- `app/controllers/app_controller.rb:242,279,316`
- `app/controllers/directory/events_controller.rb:125`

**Fix pattern:**
```ruby
# OLD:
date = Date.parse(params[:date]) rescue Date.current

# NEW:
def safe_parse_date(value)
  Date.parse(value)
rescue ArgumentError, TypeError
  Date.current
end

date = safe_parse_date(params[:date])
```

Or use `Date.strptime` if the format is known:
```ruby
Date.strptime(params[:date], '%Y-%m-%d')
```

### Phase 9 Commit

```bash
git add app/controllers/inventories_controller.rb app/controllers/app_controller.rb app/controllers/directory/events_controller.rb
git commit -m "fix: harden Date.parse with explicit rescue for Ruby 3.4 compatibility"
```

---

## Phase 10: wkhtmltopdf Replacement (Separate Project)

### 10.1 The problem

`wkhtmltopdf-binary` 0.12.6 (2018) relies on Qt WebKit, abandoned since 2016. Modern OS Ruby 3.4 + newer Ubuntu/Debian ship incompatible libssl/libpng. The binary will silently fail.

### 10.2 Options

| Option | Pros | Cons |
|--------|------|------|
| **grover** (Puppeteer/Chromium) | Modern, maintained, better CSS/JS support | Requires Chromium on server (~200MB) |
| **ferrum-pdf** (Ferrum + Chrome) | Same core as grover, simpler API | Same Chromium requirement |
| **puppeteer-ruby** | Direct headless Chrome control | Heavy dependency, overkill for PDFs |
| **Keep wkhtmltopdf** | No code changes | Will break eventually. Test on target OS. |

### 10.3 Recommended: grover

```ruby
# Gemfile
gem "grover", "~> 1.1"

# config/initializers/grover.rb
Grover.configure do |config|
  config.options = {
    format: 'A4',
    margin: { top: '10mm', bottom: '10mm', left: '10mm', right: '10mm' },
    print_background: true
  }
end
```

**Replace in controllers:**
```ruby
# OLD:
render pdf: "file", template: "path/template", ...

# NEW:
html = render_to_string(template: "path/template", layout: "pdf")
send_data Grover.new(html).to_pdf, filename: "file.pdf", type: "application/pdf"
```

### Phase 10: Deferred

This is a separate project. The remaining phases 1-9 can proceed without it. wkhtmltopdf will continue working on the current OS/Ruby combination until the server is upgraded.

---

## Execution Order

| Phase | What | Effort | Dependencies |
|-------|------|--------|-------------|
| **1** | Critical blockers (rack, byebug, FK, form_tag, wicked_pdf) | 1-2 days | None |
| **2** | form_for → form_with (13 views) | 0.5 day | Phase 1 |
| **3** | Bump load_defaults (7.0 → 7.1 → 7.2 → 8.0) | 2-3 days | Phase 1, 2 |
| **4** | Gem version bumps (puma, redis, pagy) | 1 day | Phase 3 |
| **5** | Grape API (AMS → entity, pagination, SQL fix) | 2-3 days | Phase 3 |
| **6** | SQLite FKs + data integrity | 0.5 day | Phase 1 |
| **7** | View/asset cleanup (Propshaft optional) | 1 day | Phase 3 |
| **8** | Dead code + business logic cleanup | 1 day | None |
| **9** | Date.parse hardening | 0.5 day | None |
| **10** | wkhtmltopdf replacement | Separate project | Deferred |

**Total estimated effort:** 8-12 days for phases 1-9. Phase 10 deferred indefinitely.

---

## Rollback Plan

If the upgrade fails:

1. **Gemfile:** Revert to the old `Gemfile.lock` (commit it before starting)
2. **Database:** Run `rails db:rollback` for any new migrations
3. **Views:** Revert the `form_for` → `form_with` changes
4. **Config:** Set `config.load_defaults 7.0` back
5. **Server:** Deploy old code, verify health

Take a database backup before Phase 3:
```bash
cp db/development.sqlite3 db/development.sqlite3.pre-rails8-backup
```

---

## Post-Upgrade Verification Checklist

- [ ] `bin/rails server -p 3000` boots without errors
- [ ] `bin/rails test` passes (or shows only pre-existing failures)
- [ ] All Devise flows work (login, logout, signup, password reset)
- [ ] Inventory list loads (uses StockLevel if refactored, or SUM query if not)
- [ ] Goods receipt creates Itemin + Inventory + StockLevel
- [ ] QR code generation works (test `CreateQrService.svg("test")`)
- [ ] PDF generation works (test `inventories/movements/:type/:id/label`)
- [ ] Excel import works (test `inventories/import`)
- [ ] API endpoints respond (`/api/v1/prows`, `/api/v1/tempestas`)
- [ ] QR scanner JS works (test `mainware/searchqr` with camera)
- [ ] Capistrano deploy still works (if used in production)
- [ ] `tailwindcss:watch` compiles CSS without errors
