# Excel Import with Editable Preview — Implementation Plan

## Architecture

```
Upload Excel → Parse → Store in Rails.cache → Show preview table with raw Excel headers
         ↓
User edits cells inline (Stimulus debounced PUT) → Update cache row
         ↓
User deletes row (confirmation → DELETE) → Remove from cache + DOM
         ↓
User confirms (POST) → Save all rows to Item model → Show summary card → Click → mainware/index
```

**Cache:** `Rails.cache`, key `"import:#{session.id}"`, TTL 30 min
**Editing:** Debounced 300ms PUT requests per cell
**Row deletion:** Confirmation dialog + Turbo Stream DOM removal
**Gencode:** Read-only column, auto-updates live via JS when itemcode/fabricode/varcode change
**Summary card:** Brief stats after import, click to continue

---

## Step 1: Refactor `app/services/import_general_service.rb`

**Current state:** 41 lines, single `call(file)` method with bugs (nil concatenation, broken `codecheck != []`, redundant spreadsheet open)

**Replace entire file with:**

```ruby
class ImportGeneralService
  require 'roo'

  FIELD_MAP = {
    'Item Code:'    => :itemcode,
    'Fabric code:'  => :fabricode,
    'var. code:'    => :varcode,
    'Description: ' => :description,
    'Fabric:'       => :fabric,
    'Tg.'           => :tg,
    'Note:'         => :note,
    'Colour:'       => :colour,
    'unit price'    => :unit_price,
    'materiale'     => :materiale
  }

  def parse(file)
    spreadsheet = Roo::Excelx.new(file)
    headers = spreadsheet.row(1)

    rows = (2..spreadsheet.last_row).map do |i|
      row = Hash[[headers, spreadsheet.row(i)].transpose]
      row[:_index] = i
      row[:_gencode] = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join
      row
    end

    { headers: headers, rows: rows }
  end

  def save(data)
    stats = { total: 0, created: 0, updated: 0, errors: [] }

    data[:rows].each do |row|
      stats[:total] += 1
      gencode = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join

      begin
        item = Item.find_or_initialize_by(gencode: gencode)
        stats[item.persisted? ? :updated : :created] += 1

        FIELD_MAP.each do |header, field|
          val = row[header]
          val = val.to_f if field == :unit_price
          item[field] = val
        end

        item.gencode = gencode
        item.save!
      rescue => e
        stats[:errors] << { row: row[:_index], error: e.message }
      end
    end

    stats
  end
end
```

**Key changes:**
- `parse(file)` returns `{ headers: [...], rows: [...] }` with `_index` (Excel row number) and `_gencode` (computed)
- `save(data)` uses `FIELD_MAP` to map Excel headers to Item model attributes
- `gencode` computed dynamically on save, not stored from cache
- Removed redundant `Roo::Spreadsheet.open` + `Roo::Excelx.new` double-open
- `save` now returns stats hash: `{ total:, created:, updated:, errors: [] }`
- **Note:** `colour` (British spelling) matches the actual DB column name

---

## Step 2: Add Routes to `config/routes.rb`

**Location:** Line 11-15 (after existing `get 'mainware/import'`)

**Add these 6 lines:**

```ruby
post   'mainware/import/parse',      to: 'mainware#import_parse'
put    'mainware/import/update_row', to: 'mainware#import_update_row'
delete 'mainware/import/delete_row', to: 'mainware#import_delete_row'
post   'mainware/import/confirm',    to: 'mainware#import_confirm'
delete 'mainware/import/cancel',     to: 'mainware#import_cancel'
get    'mainware/import/summary',    to: 'mainware#import_summary'
```

**Resulting block:**
```ruby
get 'mainware/index'
get 'mainware/search'
get 'mainware/import'
post   'mainware/import/parse',      to: 'mainware#import_parse'
put    'mainware/import/update_row', to: 'mainware#import_update_row'
delete 'mainware/import/delete_row', to: 'mainware#import_delete_row'
post   'mainware/import/confirm',    to: 'mainware#import_confirm'
delete 'mainware/import/cancel',     to: 'mainware#import_cancel'
get    'mainware/import/summary',    to: 'mainware#import_summary'
get 'mainware/dashboard'
get 'mainware/searchqr'
```

**Named routes generated:**
- `mainware_import_parse_path`
- `mainware_import_update_row_path`
- `mainware_import_delete_row_path`
- `mainware_import_confirm_path`
- `mainware_import_cancel_path`
- `mainware_import_summary_path`

---

## Step 3: Add Controller Actions to `app/controllers/mainware_controller.rb`

**Current state:** 30 lines, 4 actions (index, dashboard, import, search, searchqr)

**Add private helper at bottom:**
```ruby
private

def import_cache_key
  "import:#{session.id.to_s}"
end
```

**Rewrite `import` action (lines 14-23):**
```ruby
def import
  @data = Rails.cache.read(import_cache_key)
end
```

**Add 7 new actions after `import`:**

```ruby
def import_parse
  return redirect_to mainware_import_path, alert: "Seleziona un file" unless params[:file].present?

  service = ImportGeneralService.new
  data = service.parse(params[:file])
  Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
  redirect_to mainware_import_path, notice: "#{data[:rows].size} righe caricate. Verifica e modifica."
end

def import_update_row
  data = Rails.cache.read(import_cache_key)
  return head :not_found unless data

  row_index = params[:row_index].to_i
  field = params[:field]
  value = params[:value]

  row = data[:rows].find { |r| r[:_index] == row_index }
  return head :not_found unless row

  row[field] = value

  if ['Item Code:', 'Fabric code:', 'var. code:'].include?(field)
    row[:_gencode] = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join
  end

  Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
  render json: { success: true, gencode: row[:_gencode] }
end

def import_delete_row
  data = Rails.cache.read(import_cache_key)
  return head :not_found unless data

  row_index = params[:row_index].to_i
  data[:rows].reject! { |r| r[:_index] == row_index }

  Rails.cache.write(import_cache_key, data, expires_in: 30.minutes)
  respond_to { |format| format.turbo_stream }
end

def import_confirm
  data = Rails.cache.read(import_cache_key)
  return redirect_to mainware_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

  stats = ImportGeneralService.new.save(data)
  Rails.cache.delete(import_cache_key)
  Rails.cache.write("import:stats:#{session.id}", stats, expires_in: 5.minutes)
  redirect_to mainware_import_summary_path
end

def import_summary
  @stats = Rails.cache.read("import:stats:#{session.id}")
  return redirect_to mainware_index_path unless @stats
end

def import_cancel
  Rails.cache.delete(import_cache_key)
  redirect_to mainware_import_path, notice: "Importazione annullata."
end
```

**Action summary:**

| Action | Method | Purpose | Response |
|--------|--------|---------|----------|
| `import` | GET | Show upload form or preview | HTML view |
| `import_parse` | POST | Parse Excel, write to cache | Redirect back |
| `import_update_row` | PUT | Update single cell in cache | JSON `{ success, gencode }` |
| `import_delete_row` | DELETE | Remove row from cache | Turbo Stream |
| `import_confirm` | POST | Save all rows to Items | Redirect to summary |
| `import_summary` | GET | Show brief stats card | HTML summary view |
| `import_cancel` | DELETE | Clear cache and return to upload | Redirect to import |

---

## Step 4: Create Stimulus Controller `app/javascript/controllers/inline_edit_controller.js`

**New file.** Create at: `app/javascript/controllers/inline_edit_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "gencode", "row"]

  initialize() {
    this.timeouts = {}
  }

  async update(event) {
    const input = event.target
    const row = input.closest("tr")
    const rowIndex = row.dataset.rowIndex
    const field = input.dataset.field
    const value = input.value

    const key = `${rowIndex}-${field}`
    clearTimeout(this.timeouts[key])

    input.dataset.editing = "true"

    this.timeouts[key] = setTimeout(async () => {
      try {
        const response = await fetch("/mainware/import/update_row", {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
          },
          body: JSON.stringify({ row_index: rowIndex, field, value })
        })

        if (!response.ok) throw new Error("Update failed")

        const json = await response.json()

        if (["Item Code:", "Fabric code:", "var. code:"].includes(field)) {
          const gencodeEl = row.querySelector("[data-inline-edit-target='gencode']")
          if (gencodeEl) gencodeEl.textContent = json.gencode
        }

        input.dataset.editing = "saved"
        setTimeout(() => { delete input.dataset.editing }, 1000)
      } catch (error) {
        input.dataset.editing = "error"
        setTimeout(() => {
          delete input.dataset.editing
          input.value = input.defaultValue
        }, 1500)
      }
    }, 300)
  }

  deleteRow(event) {
    const row = event.currentTarget.closest("tr")
    if (!confirm("Eliminare questa riga?")) return

    const rowIndex = row.dataset.rowIndex

    fetch(`/mainware/import/delete_row?row_index=${rowIndex}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    }).then(async response => {
      const html = await response.text()
      Turbo.renderStreamMessage(html)

      const countEl = document.getElementById("import-count")
      if (countEl) {
        const current = parseInt(countEl.textContent)
        countEl.textContent = current - 1
      }
    })
  }
}
```

**Behavior:**
- `update(event)`: Debounces 300ms per cell, PUTs to server, green/red flash feedback
- `deleteRow(event)`: Shows `confirm()` dialog, DELETE request, parses Turbo Stream, updates count badge
- `data-editing` attribute states: `"true"` (in-flight), `"saved"` (success), `"error"` (failed)

---

## Step 5: Create Turbo Stream View `app/views/mainware/import_delete_row.turbo_stream.erb`

**New file.** Create at: `app/views/mainware/import_delete_row.turbo_stream.erb`

```erb
<%= turbo_stream.remove "row-#{params[:row_index]}" %>
```

**What this does:** When the DELETE request succeeds, Rails renders this Turbo Stream template which removes the `<tr id="row-X">` element from the DOM.

---

## Step 6: Create Summary View `app/views/mainware/import_summary.html.erb`

**New file.** Create at: `app/views/mainware/import_summary.html.erb`

**This view renders a brief stats card after import confirmation.**

```erb
<div class="<%= style_main_header_container %>">
  <%= render partial: 'atoms/header', locals: {link: '/', label: 'Generale / Import'} %>
</div>

<section class="<%= style_main_cnt %>">
  <div class="max-w-md mx-auto bg-white border border-slate-200 rounded-lg p-8 text-center">
    <h2 class="text-2xl font-bold text-slate-800 mb-6">Importazione completata</h2>

    <div class="grid grid-cols-2 gap-4 mb-8">
      <div class="bg-slate-50 p-4 rounded-lg">
        <p class="text-3xl font-bold text-slate-700"><%= @stats[:total] %></p>
        <p class="text-xs text-slate-500 uppercase">Righe processate</p>
      </div>

      <div class="bg-green-50 p-4 rounded-lg">
        <p class="text-3xl font-bold text-green-700"><%= @stats[:created] %></p>
        <p class="text-xs text-green-600 uppercase">Nuovi</p>
      </div>

      <div class="bg-blue-50 p-4 rounded-lg">
        <p class="text-3xl font-bold text-blue-700"><%= @stats[:updated] %></p>
        <p class="text-xs text-blue-600 uppercase">Aggiornati</p>
      </div>

      <div class="<%= @stats[:errors].any? ? 'bg-red-50' : 'bg-slate-50' %> p-4 rounded-lg">
        <p class="text-3xl font-bold <%= @stats[:errors].any? ? 'text-red-700' : 'text-slate-300' %>"><%= @stats[:errors].size %></p>
        <p class="text-xs <%= @stats[:errors].any? ? 'text-red-600' : 'text-slate-400' %> uppercase">Errori</p>
      </div>
    </div>

    <% if @stats[:errors].any? %>
      <div class="text-left bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
        <p class="text-sm font-semibold text-red-800 mb-2">Dettagli errori:</p>
        <ul class="text-xs text-red-700 space-y-1">
          <% @stats[:errors].each do |err| %>
            <li>Riga <%= err[:row] %>: <%= err[:error] %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <%= link_to mainware_index_path, class: "block w-full #{style_import_btn} bg-green-600 text-center cursor-pointer" do %>
      Vai alla lista articoli
    <% end %>
  </div>
</section>
```

**What it shows:**
- 4 stat boxes: Total, New, Updated, Errors
- If any errors occurred, a red box with row number + error message per failure
- Single clickable button/card: "Vai alla lista articoli" → navigates to `mainware_index_path`

---

## Step 7: Rewrite `app/views/mainware/import.html.erb`

**Current state:** Empty (1 line with just whitespace)

**Replace entire file with:**

```erb
<div class="<%= style_main_header_container %>">
  <%= render partial: 'atoms/header', locals: {link: '/', label: 'Generale / Import'} %>
</div>

<section class="<%= style_main_cnt %>">
  <% if @data.present? %>

    <h2 class="<%= style_main_sub_header %>">
      Anteprima importazione (<span id="import-count"><%= @data[:rows].size %></span> righe)
    </h2>

    <div class="overflow-x-auto max-h-[800px] overflow-y-auto">
      <table class="w-full" data-controller="inline-edit">
        <thead>
          <tr>
            <th class="<%= style_table_th %> sticky top-0 z-10"></th>
            <th class="<%= style_table_th %> sticky top-0 z-10">Riga</th>
            <th class="<%= style_table_th %> sticky top-0 z-10">Gencode</th>
            <% @data[:headers].each do |h| %>
              <th class="<%= style_table_th %> sticky top-0 z-10"><%= h %></th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <% @data[:rows].each do |row| %>
            <tr id="row-<%= row[:_index] %>"
                data-row-index="<%= row[:_index] %>"
                data-inline-edit-target="row"
                class="hover:bg-slate-50">

              <td class="<%= style_table_td %> text-center">
                <button type="button"
                        data-action="inline-edit#deleteRow"
                        class="text-red-500 hover:text-red-700 cursor-pointer">
                  <span class="material-symbols-outlined text-sm">delete</span>
                </button>
              </td>

              <td class="<%= style_table_td %> text-center text-xs text-slate-400">
                <%= row[:_index] %>
              </td>

              <td class="<%= style_table_td %> text-xs font-mono text-blue-600"
                  data-inline-edit-target="gencode">
                <%= row[:_gencode] %>
              </td>

              <% @data[:headers].each do |header| %>
                <td class="<%= style_table_td %> p-0">
                  <input type="text"
                         value="<%= row[header] %>"
                         data-field="<%= header %>"
                         data-action="input->inline-edit#update"
                         data-inline-edit-target="input"
                         data-default="<%= row[header] %>"
                         class="w-full px-2 py-1 text-xs border-none bg-transparent outline-none focus:bg-blue-50" />
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <div class="flex gap-4 mt-6">
      <%= form_with url: mainware_import_confirm_path, method: :post do %>
        <button type="submit" class="<%= style_import_btn %> bg-green-600">
          Conferma importazione (<span id="import-count-btn"><%= @data[:rows].size %></span>)
        </button>
      <% end %>

      <%= button_to "Annulla", mainware_import_cancel_path, method: :delete, class: "#{style_import_btn} bg-gray-400" %>
    </div>

  <% else %>

    <section class="<%= style_import_form %>">
      <%= form_with url: mainware_import_parse_path, method: :post, multipart: true do |f| %>
        <div class="w-full flex gap-2 items-center">
          <%= f.file_field :file, class: style_import_field, required: true %>
          <%= f.submit "Carica", class: style_import_btn %>
        </div>
      <% end %>
    </section>

  <% end %>
</section>
```

**Two states:**

1. **Upload state** (`@data` nil): Shows file upload form → POST to `import_parse`
2. **Preview state** (`@data` present): Shows scrollable table with editable inputs → confirm POST or cancel

**Table columns:** `[Delete] | Riga | Gencode | <all Excel headers...>`

**Table header:** Sticky (`sticky top-0 z-10` on each `<th>`) — stays visible during vertical scroll.

**Table container height:** `max-h-[800px]` — taller scrollable area.

**Edit feedback via CSS:**
```css
[data-editing="saved"] { background-color: #dcfce7; }
[data-editing="error"] { background-color: #fee2e2; }
```

**Row deletion:** Deletes from DOM via Turbo Stream, decrements `#import-count` and `#import-count-btn` via JS.

---

## Step 8: Enable Rails.cache in Production

**File:** `config/environments/production.rb`

**Around line 59, uncomment:**
```ruby
config.cache_store = :mem_cache_store
```

**Ensure this is set (should already be in production.rb):**
```ruby
config.action_controller.perform_caching = true
```

**Already enabled in dev** (`config/environments/development.rb`, line 26):
```ruby
config.cache_store = :memory_store
```

---

## Step 9: Rewrite Index View with Items Table

**File:** `app/views/mainware/index.html.erb`

**Current state:** Shows header + link to import page + renders `_dash` partial

**Replace entire file with:**

```erb
<div class="<%= style_main_header_container %>">
  <%= render partial: 'atoms/header', locals: {link: '/', label: 'Generale / Articoli'} %>
</div>

<section class="<%= style_main_cnt %>" data-controller="search-filter">
  <div class="flex gap-4 items-center mb-4">
    <%= link_to "Importa da Excel", mainware_import_path, class: style_import_btn %>
    <span class="text-sm text-slate-500"><%= @pagy.count %> articoli totali</span>

    <input type="text"
           placeholder="Cerca in tutte le colonne..."
           data-search-filter-target="search"
           data-action="input->search-filter#filter"
           class="<%= style_search_input %> ml-auto w-80" />
  </div>

  <div class="flex gap-4 items-center mb-4">
    <select id="filter-itemcode"
            data-search-filter-target="filter"
            data-field="itemcode"
            data-action="change->search-filter#filter">
      <option value="">Item Code (tutti)</option>
      <% Item.distinct.pluck(:itemcode).compact.each do |v| %>
        <option value="<%= v %>"><%= v %></option>
      <% end %>
    </select>

    <select id="filter-fabricode"
            data-search-filter-target="filter"
            data-field="fabricode"
            data-action="change->search-filter#filter">
      <option value="">Fabric Code (tutti)</option>
      <% Item.distinct.pluck(:fabricode).compact.each do |v| %>
        <option value="<%= v %>"><%= v %></option>
      <% end %>
    </select>

    <select id="filter-varcode"
            data-search-filter-target="filter"
            data-field="varcode"
            data-action="change->search-filter#filter">
      <option value="">Var. Code (tutti)</option>
      <% Item.distinct.pluck(:varcode).compact.each do |v| %>
        <option value="<%= v %>"><%= v %></option>
      <% end %>
    </select>

    <button type="button"
            data-action="search-filter#resetFilters"
            class="text-xs text-slate-500 underline hover:text-slate-700 cursor-pointer">
      Reset filtri
    </button>
  </div>

  <div class="overflow-x-auto max-h-[800px] overflow-y-auto">
    <table class="w-full">
      <thead>
        <tr>
          <% %w[Gencode Item Code Fabric code Var. code Description Tg Fabric Colour Unit Price Materiale Note Created].each do |h| %>
            <th class="<%= style_table_th %> sticky top-0 z-10"><%= h %></th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <% @itemz.each do |item| %>
          <tr class="hover:bg-slate-50" data-search-filter-target="row">
            <td class="<%= style_table_td %> text-xs font-mono text-blue-600"><%= item.gencode %></td>
            <td class="<%= style_table_td %>" data-cell="itemcode"><%= item.itemcode %></td>
            <td class="<%= style_table_td %>" data-cell="fabricode"><%= item.fabricode %></td>
            <td class="<%= style_table_td %>" data-cell="varcode"><%= item.varcode %></td>
            <td class="<%= style_table_td %>"><%= item.description %></td>
            <td class="<%= style_table_td %>"><%= item.tg %></td>
            <td class="<%= style_table_td %>"><%= item.fabric %></td>
            <td class="<%= style_table_td %>"><%= item.colour %></td>
            <td class="<%= style_table_td %>"><%= item.unit_price %></td>
            <td class="<%= style_table_td %>"><%= item.materiale %></td>
            <td class="<%= style_table_td %>"><%= item.note %></td>
            <td class="<%= style_table_td %>"><%= item.created_at.strftime('%d-%m-%Y') if item.created_at %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <% if @pagy.pages > 1 %>
    <div class="mt-6">
      <%== pagy_nav(@pagy) %>
    </div>
  <% end %>
</section>
```

**Features:**
- Read-only table, all Item model fields as columns
- Sticky header (`sticky top-0 z-10` on each `<th>`)
- Scrollable container `max-h-[800px]`
- Pagy pagination at bottom
- "Importa da Excel" button + total count badge at top
- **Live search input** filtering across all columns as you type

---

## Step 10: Add slim-select via Importmap

**Run:**
```bash
bin/importmap pin slim-select
```

**Update `app/javascript/application.js`:**
```javascript
import SlimSelect from 'slim-select'

window.SlimSelect = SlimSelect
```

**Initialize dropdowns:** slim-select transforms standard `<select>` elements into searchable dropdowns. It will be initialized on the three filter selects (`#filter-itemcode`, `#filter-fabricode`, `#filter-varcode`) via the Stimulus controller's `connect()` method.

---

## Step 11: Create Stimulus Controller `app/javascript/controllers/search_filter_controller.js`

**New file.** Create at: `app/javascript/controllers/search_filter_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "row", "filter"]
  static values = { debounce: { type: Number, default: 150 } }

  initialize() {
    this.timeout = null
    this.originalTexts = new Map()
  }

  connect() {
    // Store original cell text for highlight restoration
    this.rowTargets.forEach(row => {
      row.querySelectorAll('td').forEach((cell, idx) => {
        const key = `${row.rowIndex}-${idx}`
        this.originalTexts.set(key, cell.textContent)
        cell.dataset.cellKey = key
      })
    })

    // Initialize slim-select on filter dropdowns
    this.filterTargets.forEach(select => {
      new SlimSelect({ select })
    })
  }

  filter() {
    const searchQuery = this.searchTarget.value.toLowerCase().trim()
    const activeFilters = this._getActiveFilters()

    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.rowTargets.forEach(row => {
        const matchesSearch = searchQuery.length === 0 || row.textContent.toLowerCase().includes(searchQuery)
        const matchesFilters = activeFilters.every(({ field, value }) => {
          const cell = row.querySelector(`td[data-cell="${field}"]`)
          return cell && cell.textContent.trim() === value
        })

        const isMatch = matchesSearch && matchesFilters
        row.hidden = !isMatch

        if (isMatch && searchQuery.length > 0) {
          this.highlightCells(row, searchQuery)
        } else if (isMatch && activeFilters.length > 0) {
          this.highlightFilters(row, activeFilters)
        } else {
          this.resetCells(row)
        }
      })
    }, this.debounceValue)
  }

  resetFilters() {
    this.filterTargets.forEach(select => {
      select.setValue('')
    })
    this.filter()
  }

  _getActiveFilters() {
    return this.filterTargets
      .filter(select => select.value !== '')
      .map(select => ({ field: select.dataset.field, value: select.value }))
  }

  highlightCells(row, query) {
    row.querySelectorAll('td').forEach(cell => {
      const key = cell.dataset.cellKey
      const original = this.originalTexts.get(key) || ''
      const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
      const regex = new RegExp(`(${escaped})`, 'gi')
      cell.innerHTML = original.replace(regex, '<mark class="bg-yellow-200 text-slate-800 rounded px-0.5">$1</mark>')
    })
  }

  highlightFilters(row, filters) {
    row.querySelectorAll('td').forEach(cell => {
      const key = cell.dataset.cellKey
      const original = this.originalTexts.get(key) || ''
      const cellField = cell.dataset.cell

      const matchingFilter = filters.find(f => f.field === cellField)
      if (matchingFilter) {
        const escaped = matchingFilter.value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        const regex = new RegExp(`(${escaped})`, 'gi')
        cell.innerHTML = original.replace(regex, '<mark class="bg-green-200 text-green-900 rounded px-0.5">$1</mark>')
      } else {
        cell.textContent = original
      }
    })
  }

  resetCells(row) {
    row.querySelectorAll('td').forEach(cell => {
      const key = cell.dataset.cellKey
      cell.textContent = this.originalTexts.get(key) || ''
    })
  }
}
```

**Behavior:**
- 150ms debounce on input event
- **Text search**: matches any column, highlights in yellow (`bg-yellow-200`)
- **Column filters**: AND logic — all active dropdown filters must match
- **Combined**: search AND column filters both apply together
- **Highlighting**:
  - Search text matches: yellow highlight
  - Column filter matches: green highlight (`bg-green-200`)
  - Both active: column filter takes precedence (green) on filtered columns, search highlights others (yellow)
- **"Reset filtri" button**: clears all dropdown filters and re-runs filter
- slim-select provides searchable dropdowns with autocomplete on each filter
  }

  highlightCells(row, query) {
    row.querySelectorAll('td').forEach(cell => {
      const key = cell.dataset.cellKey
      const original = this.originalTexts.get(key) || ''
      const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
      const regex = new RegExp(`(${escaped})`, 'gi')
      cell.innerHTML = original.replace(regex, '<mark class="bg-yellow-200 text-slate-800 rounded px-0.5">$1</mark>')
    })
  }

  resetCells(row) {
    row.querySelectorAll('td').forEach(cell => {
      const key = cell.dataset.cellKey
      cell.textContent = this.originalTexts.get(key) || ''
    })
  }
}
```

---

## Execution Order

1. **Step 1** — Service refactor (no dependencies)
2. **Step 2** — Routes (required before controller)
3. **Step 3** — Controller actions (uses service + routes)
4. **Step 4** — Stimulus controller: inline_edit (independent, can be done in parallel with 1-3)
5. **Step 5** — Turbo Stream view (required before controller DELETE action works)
6. **Step 6** — Summary view (new, uses controller stats)
7. **Step 7** — Import view rewrite (uses all of the above)
8. **Step 8** — Production cache (can be done anytime, no effect in dev)
9. **Step 9** — Index view: items table with search input + column filters (no dependencies)
10. **Step 10** — slim-select via importmap (prerequisite for Step 11)
11. **Step 11** — Search filter Stimulus controller with column filter support (uses Step 10)

---

## Files Changed

| # | File | Action | Lines ~ |
|---|------|--------|---------|
| 1 | `app/services/import_general_service.rb` | Rewrite | ~55 |
| 2 | `config/routes.rb` | Add 6 lines | +6 |
| 3 | `app/controllers/mainware_controller.rb` | Add 7 actions + helper | ~95 new |
| 4 | `app/javascript/controllers/inline_edit_controller.js` | Create | ~70 |
| 5 | `app/views/mainware/import.html.erb` | Rewrite | ~95 |
| 6 | `app/views/mainware/import_delete_row.turbo_stream.erb` | Create | 1 |
| 7 | `app/views/mainware/import_confirm.html.erb` | Create | ~50 |
| 8 | `config/environments/production.rb` | Uncomment 1 line | +1 |
| 9 | `app/views/mainware/index.html.erb` | Full rewrite with items table + search + column filters | ~85 |
| 10 | slim-select via importmap | `bin/importmap pin slim-select` | ~15KB gzip |
| 11 | `app/javascript/controllers/search_filter_controller.js` | Rewrite with column filters + dual highlighting | ~80 |

---

## Data Flow Diagram

```
User selects file
       ↓
POST /mainware/import/parse
       ↓
ImportGeneralService.parse(file) → { headers: [...], rows: [...] }
       ↓
Rails.cache.write("import:#{session.id}", data, expires_in: 30.min)
       ↓
Redirect to GET /mainware/import → renders preview table
       ↓
User edits cell → 300ms debounce → PUT /mainware/import/update_row
       ↓
Find row in cache by _index → update field → recompute _gencode → write back
       ↓
Return { success: true, gencode: "..." } → JS updates gencode cell + green flash
       ↓
User clicks delete → confirm() → DELETE /mainware/import/delete_row
       ↓
Reject row from cache array → write back → turbo_stream.remove "row-X"
       ↓
User clicks "Conferma importazione" → POST /mainware/import/confirm
       ↓
ImportGeneralService.save(data) → find_or_initialize_by(gencode) → save → returns stats
       ↓
Rails.cache.delete("import:#{session.id}") → write stats to "import:stats:#{session.id}"
       ↓
Redirect to GET /mainware/import/summary → render summary card
       ↓
User clicks "Vai alla lista articoli" → redirect to /mainware/index
       ↓
User clicks "Annulla" → DELETE /mainware/import/cancel
       ↓
Rails.cache.delete("import:#{session.id}") → redirect to /mainware/import (upload state)
```

---

## Testing Checklist

- [ ] Upload valid Excel file → preview table shows with correct headers and row count
- [ ] Table header stays sticky during vertical scroll
- [ ] Table container height is ~800px
- [ ] Edit a cell → wait 300ms → green flash confirms save
- [ ] Edit `Item Code:` → gencode column updates live from server response
- [ ] Edit `Fabric code:` → gencode updates
- [ ] Edit `var. code:` → gencode updates
- [ ] Delete a row → confirmation dialog → row disappears from DOM + cache
- [ ] Delete last remaining row → table empty, confirm button shows (0)
- [ ] Confirm import → rows saved, cache cleared, redirect to summary card (no Turbo error)
- [ ] Summary card shows: total, new, updated, errors
- [ ] Summary card shows error details when failures occur
- [ ] Click summary card button → navigates to `mainware_index_path`
- [ ] Cancel import (Annulla) → cache cleared, back to upload state
- [ ] Refresh page during preview → cache still there (30 min TTL)
- [ ] Upload empty/invalid file → error alert shown
- [ ] Upload Excel with unknown headers → headers show in table but ignored on save
- [ ] Upload Excel with nil cells → handled gracefully (no crash)
- [ ] Gencode correctly computed on save from current cell values
- [ ] `find_or_initialize_by(gencode)` correctly finds existing items vs creates new
- [ ] `colour` field maps correctly to DB column (not `color`)
- [ ] Production environment: cache properly configured and functional
- [ ] Index page shows paginated items table with all Item fields
- [ ] Index table header is sticky during scroll
- [ ] Index table container is ~800px tall
- [ ] Pagy pagination works on index page
- [ ] Search input filters all columns as you type (client-side)
- [ ] Search has 150ms debounce (no lag on fast typing)
- [ ] Clearing search input restores all rows immediately
- [ ] Search is case-insensitive
- [ ] Column filter dropdowns show all distinct values for itemcode, fabricode, varcode
- [ ] slim-select transforms dropdowns into searchable selects with autocomplete
- [ ] Column filters work with AND logic (all must match simultaneously)
- [ ] Search text and column filters combine (both apply together)
- [ ] Search matches highlighted in yellow (`bg-yellow-200`)
- [ ] Column filter matches highlighted in green (`bg-green-200`)
- [ ] "Reset filtri" button clears all column filters and restores full table
- [ ] Only rows matching ALL active filters + search text remain visible
