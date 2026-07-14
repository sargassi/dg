# Archive — Import from Main Warehouse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow warehouse items to be moved out (scarico) and become archive items, linked to the originating Inventory record.

**Architecture:** Add `inventory_id` FK to `archive_items`. Two entry points: a sidebar autocomplete/QR on the existing archive index page (quick single-item import), and a dedicated batch selection page modeled after `inventories/seleziona`. The scarico flow reuses the existing Itemout infrastructure; archive items are created with data copied from mainware Items.

**Tech Stack:** Rails 7.0.7, Ruby 3.2.2, SQLite, Turbo, Stimulus, Active Storage, Pagy

## Global Constraints

- All new code follows existing project conventions (importmaps, Turbo Drive, Stimulus)
- Archive models under `Archive::` namespace
- `inventory_id` FK references `inventories.id` (nullable)
- No changes to mainware models (Item, Inventory, Itemout, StockLevel)
- Use existing Stimulus controllers where possible (`autocomplete`, `seleziona`, `qr-scanner`, `image-preview`)

---

### Task 1: Migration + Model update

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_inventory_id_to_archive_items.rb`
- Modify: `app/models/archive/item.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration AddInventoryIdToArchiveItems inventory:references
```

- [ ] **Step 2: Edit migration to add FK and index**

Edit the generated migration file:

```ruby
class AddInventoryIdToArchiveItems < ActiveRecord::Migration[7.0]
  def change
    add_reference :archive_items, :inventory, foreign_key: true, null: true
  end
end
```

- [ ] **Step 3: Run migration**

```bash
bin/rails db:migrate
```

- [ ] **Step 4: Update model**

Edit `app/models/archive/item.rb` — add `belongs_to :inventory, optional: true` inside the module:

```ruby
module Archive
  class Item < ApplicationRecord
    belongs_to :category, class_name: "Archive::Category", foreign_key: :archive_category_id, optional: true
    belongs_to :location, class_name: "Archive::Location", foreign_key: :archive_location_id, optional: true
    belongs_to :inventory, optional: true
    # ... rest of model unchanged
  end
end
```

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ app/models/archive/item.rb
git commit -m "feat: add inventory_id to Archive::Item for warehouse link"
```

---

### Task 2: Routes + Warehouse search endpoint

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/archive/items_controller.rb`

- [ ] **Step 1: Add routes**

Edit `config/routes.rb` — add collection routes inside the archive items resource:

```ruby
namespace :archive do
  resources :items do
    collection do
      get :qrcodes, defaults: { format: :pdf }
      get :warehouse_search
      get :import
      post :import_itemout
      post :import_confirm
    end
    member do
      post :checkout
      post :checkin
      post :duplicate
    end
  end
  # ... rest unchanged
end
```

- [ ] **Step 2: Add `warehouse_search` action**

Edit `app/controllers/archive/items_controller.rb` — add the action before `private`:

```ruby
def warehouse_search
  q = "%#{params[:q]}%"
  items = Item.where(
    "gencode LIKE :q OR itemcode LIKE :q OR fabricode LIKE :q OR varcode LIKE :q OR description LIKE :q",
    q: q
  ).select(:id, :gencode, :itemcode, :fabricode, :varcode, :description, :collection_id).limit(20)

  gencodes = items.map(&:gencode).compact
  stock = StockLevel.where(gencode: gencodes).positive.group(:gencode)
    .select(:gencode, Arel.sql("SUM(current_qty) AS total_qty"))
    .index_by(&:gencode)

  render json: items.map { |item|
    {
      id: item.id,
      gencode: item.gencode,
      itemcode: item.itemcode,
      fabricode: item.fabricode,
      varcode: item.varcode,
      description: item.description,
      label: "#{item.itemcode}#{item.fabricode}#{item.varcode}",
      collection_id: item.collection_id,
      stock_available: stock[item.gencode]&.total_qty || 0
    }
  }
end
```

- [ ] **Step 3: Verify routes**

```bash
bin/rails routes | grep archive/items/warehouse_search
# Expected: GET /archive/items/warehouse_search(.:format) archive/items#warehouse_search
```

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb app/controllers/archive/items_controller.rb
git commit -m "feat: add warehouse_search endpoint for archive import autocomplete"
```

---

### Task 3: Right sidebar autocomplete panel

**Files:**
- Modify: `app/views/archive/items/index.html.erb`

- [ ] **Step 1: Add "Importa da magazzino" panel to the right sidebar**

Edit `app/views/archive/items/index.html.erb`. Find the sidebar section (the `w-80` div containing "Nuovo articolo") and add the import panel below it. The import panel includes both autocomplete search and QR scan:

```erb
<div class="w-80 flex-shrink-0 ml-4 space-y-4">
  <div class="<%= style_main_card %>">
    <div class="<%= style_main_card_header %>">
      <span class="material-symbols-outlined text-lg">add</span>
      Nuovo articolo
    </div>
    <%= render 'form', item: @new_item %>
  </div>

  <div class="<%= style_main_card %>" data-controller="autocomplete row-qr" data-autocomplete-url-value="<%= warehouse_search_archive_items_path %>" data-autocomplete-min-length-value="2">
    <div class="<%= style_main_card_header %>">
      <span class="material-symbols-outlined text-lg">inventory_2</span>
      Importa da magazzino
    </div>
    <div class="p-3 space-y-3">
      <div class="flex items-center gap-2">
        <div class="relative flex-1">
          <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-base pointer-events-none">search</span>
          <input type="text"
                 data-autocomplete-target="input"
                 data-row-qr-target="input"
                 data-action="input->autocomplete#search"
                 class="w-full border border-slate-300 outline-none px-3 py-2 pl-10 text-xs rounded-sm dark:bg-slate-700 dark:text-slate-200 dark:border-slate-600"
                 placeholder="Cerca per codice...">
          <ul data-autocomplete-target="results"
              class="hidden absolute z-50 left-0 right-0 mt-1 bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-sm shadow-lg max-h-60 overflow-y-auto text-xs">
          </ul>
          <input type="hidden" data-autocomplete-target="hidden" name="item_id">
        </div>
        <button type="button"
                data-action="row-qr#scan"
                data-row-qr-target="button"
                class="p-2 text-slate-400 hover:text-accent rounded-sm hover:bg-slate-100 dark:hover:bg-slate-700"
                title="Scansiona QR">
          <span class="material-symbols-outlined text-base">qr_code_scanner</span>
        </button>
      </div>

      <!-- QR overlay -->
      <div data-row-qr-target="overlay"
           class="hidden fixed inset-0 z-50 bg-black/80 flex items-center justify-center">
        <div class="relative bg-white dark:bg-slate-800 rounded-xl p-4 w-full max-w-sm mx-4">
          <video data-row-qr-target="video"
                 class="w-full aspect-square bg-black rounded-lg object-cover"
                 autoplay playsinline></video>
          <button type="button" data-action="row-qr#stop"
                  class="mt-3 w-full px-4 py-2 bg-slate-700 text-white text-xs rounded-sm hover:bg-slate-600 cursor-pointer">
            Chiudi
          </button>
        </div>
      </div>

      <div data-autocomplete-target="info" class="hidden space-y-2 text-xs">
        <div class="flex justify-between items-center p-2 bg-slate-50 dark:bg-slate-700/50 rounded-sm">
          <div>
            <span class="font-mono text-blue-600" data-target="gencode"></span>
            <span class="text-slate-400 ml-2" data-target="description"></span>
          </div>
          <span class="text-green-600 font-medium" data-target="stock"></span>
        </div>

        <div class="flex gap-2">
          <%= link_to inventarios_itemouts_path, class: "flex-1 px-3 py-1.5 bg-amber-500 hover:bg-amber-600 text-white text-xs rounded-sm text-center font-medium", data: { turbo_frame: "_top" } do %>
            <span class="material-symbols-outlined text-sm align-middle">logout</span>
            Scarica
          <% end %>
          <%= link_to new_archive_item_path, class: "flex-1 px-3 py-1.5 bg-accent hover:bg-accent-700 text-white text-xs rounded-sm text-center font-medium", data: { turbo_frame: "item_modal" } do %>
            <span class="material-symbols-outlined text-sm align-middle">archive</span>
            Crea in archivio
          <% end %>
        </div>
      </div>
    </div>
  </div>
</div>
```

Then remove the old sidebar wrapper (the single `w-80 flex-shrink-0 ml-4` div that wraps only "Nuovo articolo") and replace with the new wrapper that contains both cards.

- [ ] **Step 2: Verify the view renders**

```bash
bin/rails server -p 3001 &
curl -s http://localhost:3001/archive/items | grep -o "Importa da magazzino"
# Expected: Importa da magazzino
kill %1 2>/dev/null
```

- [ ] **Step 3: Commit**

```bash
git add app/views/archive/items/index.html.erb
git commit -m "feat: add warehouse import autocomplete panel to archive sidebar"
```

---

### Task 4: Batch import page

**Files:**
- Create: `app/views/archive/items/import.html.erb`
- Create: `app/views/archive/items/_import_item_row.html.erb`
- Modify: `app/controllers/archive/items_controller.rb`
- Modify: `app/views/layouts/menus/side/_structure.html.erb` (add sidebar link)

- [ ] **Step 1: Add `import` action to controller**

Edit `app/controllers/archive/items_controller.rb` — add the import action before `warehouse_search`:

```ruby
def import
  @collections = Collection.joins(:items).distinct.order(row_order: :desc)

  @items = Item.includes(:collection).with_attached_pictures
    .joins(:stock_levels)
    .where(stock_levels: { current_qty: 1.. })

  if params[:collection_id].present?
    @items = @items.where(collection_id: params[:collection_id])
  end

  if params[:q].present?
    q = "%#{params[:q]}%"
    @items = @items.where(
      "items.gencode LIKE :q OR items.itemcode LIKE :q OR items.fabricode LIKE :q OR items.varcode LIKE :q OR items.description LIKE :q",
      q: q
    )
  end

  @items = @items.distinct
  @pagy, @items = pagy(@items)
end
```

- [ ] **Step 2: Create the import view**

Create `app/views/archive/items/import.html.erb`:

```erb
<% content_for :page_header do %>
<div class="flex items-center gap-4 px-0 py-0.5">
  <h1 class="text-sm font-semibold text-slate-500 dark:text-slate-400 tracking-wide">
    Importa da magazzino
  </h1>
</div>
<% end %>

<section class="<%= style_main_cnt %> flex flex-row" style="height: calc(100vh - 110px);" data-controller="seleziona search-filter">

  <div class="flex flex-col flex-1 min-w-0">
    <div class="flex gap-4 items-center mb-4 flex-none">
      <%= form_with url: import_archive_items_path, method: :get,
                    data: { search_filter_target: "form", turbo_frame: "import-items" },
                    class: "flex items-center gap-3" do |f| %>
        <div class="relative">
          <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-base pointer-events-none">search</span>
          <%= f.search_field :q,
                value: params[:q],
                placeholder: "Cerca articoli...",
                class: "#{style_search_input} rounded-lg pl-10 font-mono text-blue-600",
                data: { action: "input->search-filter#filter", search_filter_target: "input" } %>
        </div>
        <%= f.collection_select :collection_id, @collections, :id, :description,
              { include_blank: "Tutte le collezioni", selected: params[:collection_id] },
              class: "border border-accent-100 outline-none p-2 text-xs bg-white rounded-lg shadow-sm w-40",
              data: { search_filter_target: "select", action: "change->search-filter#filter" } %>
      <% end %>
      <span class="text-sm font-bold text-slate-700 whitespace-nowrap border border-slate-300 rounded-full px-3 py-1" data-search-filter-target="count"><%= @pagy.count %> articoli disponibili</span>
    </div>

    <style>
      turbo-frame#import-items[busy] .import-items-content { display: none; }
      turbo-frame#import-items[busy] .import-items-loader { display: flex; }
    </style>
    <%= turbo_frame_tag "import-items", class: "flex flex-col flex-1 min-h-0", data: { action: "turbo:frame-load->search-filter#onFrameLoad turbo:frame-load->seleziona#syncFrame" } do %>
      <div class="import-items-content flex flex-col flex-1 min-h-0">
        <div class="overflow-x-auto flex-1 min-h-0 overflow-y-auto">
          <table class="min-w-full">
            <thead>
              <tr>
                <th class="<%= style_table_th %> sticky top-0 z-10 w-10"></th>
                <th class="<%= style_table_th %> sticky top-0 z-10 w-12">Img</th>
                <% %w[Gencode Item Fabric Var Descrizione Collezione].each do |h| %>
                  <th class="<%= style_table_th %> sticky top-0 z-10"><%= h %></th>
                <% end %>
              </tr>
            </thead>
            <%= render partial: 'import_item_row', collection: @items, as: :item %>
          </table>
        </div>

        <% if @pagy.pages > 1 %>
          <div class="flex-none flex items-center gap-0.5 justify-end pt-3 pb-1">
            <% if @pagy.prev %>
              <a href="<%= pagy_url_for(@pagy, @pagy.prev) %>"
                 data-turbo-frame="import-items"
                 class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm text-slate-700 hover:bg-slate-100 transition-colors">
                <span class="material-symbols-outlined text-base">chevron_left</span>
              </a>
            <% else %>
              <span class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm text-slate-300 pointer-events-none">
                <span class="material-symbols-outlined text-base">chevron_left</span>
              </span>
            <% end %>
            <% @pagy.series.each do |pag_item| %>
              <% if pag_item.is_a?(Integer) %>
                <a href="<%= pagy_url_for(@pagy, pag_item) %>"
                   data-turbo-frame="import-items"
                   class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm text-slate-700 hover:bg-slate-100 transition-colors">
                  <%= pag_item %>
                </a>
              <% elsif pag_item == :gap %>
                <span class="px-1 text-slate-400 text-xs">…</span>
              <% elsif pag_item == @pagy.page %>
                <span class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm bg-accent text-white font-medium">
                  <%= pag_item %>
                </span>
              <% end %>
            <% end %>
            <% if @pagy.next %>
              <a href="<%= pagy_url_for(@pagy, @pagy.next) %>"
                 data-turbo-frame="import-items"
                 class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm text-slate-700 hover:bg-slate-100 transition-colors">
                <span class="material-symbols-outlined text-base">chevron_right</span>
              </a>
            <% else %>
              <span class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm text-slate-300 pointer-events-none">
                <span class="material-symbols-outlined text-base">chevron_right</span>
              </span>
            <% end %>
          </div>
        <% end %>
      </div>

      <div class="import-items-loader hidden justify-center items-center py-12">
        <svg class="animate-spin h-10 w-10 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span class="ml-3 text-slate-600">Ricerca in corso...</span>
      </div>
    <% end %>
  </div>

  <div data-seleziona-target="basket"
       class="hidden w-80 flex-shrink-0 ml-4 bg-white border-l-2 border-accent shadow-lg flex flex-col overflow-hidden">
    <div class="px-4 py-3 border-b border-slate-200">
      <span class="text-sm font-semibold text-slate-700" data-seleziona-target="basketCount">0 articoli selezionati</span>
    </div>
    <div class="flex-1 overflow-y-auto px-4 py-2 space-y-2" data-seleziona-target="basketItems">
    </div>
    <div class="px-4 py-3 border-t border-slate-200 space-y-2">
      <form action="<%= import_itemout_archive_items_path %>" method="POST" data-seleziona-target="form">
        <div data-seleziona-target="hiddenInputs"></div>
        <div class="space-y-2">
          <button type="submit" class="w-full px-4 py-2 text-sm tracking-wide text-white rounded-sm bg-amber-500 hover:bg-amber-600 font-medium">
            <span class="material-symbols-outlined text-sm align-middle">logout</span>
            Scarica da magazzino
          </button>
          <button type="submit" formaction="<%= import_confirm_archive_items_path %>"
                  class="w-full px-4 py-2 text-sm tracking-wide text-white rounded-sm bg-accent hover:bg-accent-700 font-medium">
            <span class="material-symbols-outlined text-sm align-middle">archive</span>
            Importa in archivio
          </button>
        </div>
      </form>
    </div>
  </div>
</section>
```

- [ ] **Step 3: Create the row partial**

Create `app/views/archive/items/_import_item_row.html.erb`:

```erb
<tbody>
  <tr class="hover:bg-slate-50 transition-colors">
    <td class="<%= style_table_td %> text-center">
      <input type="checkbox"
             data-seleziona-target="checkbox"
             data-action="change->seleziona#toggleItem"
             data-id="<%= item.id %>"
             data-gencode="<%= item.gencode %>"
             data-collection-id="<%= item.collection_id %>"
             data-collection="<%= item.collection&.description %>"
             data-itemcode="<%= item.itemcode %>"
             class="rounded border-slate-300 text-accent focus:ring-accent cursor-pointer">
    </td>
    <td class="<%= style_table_td %> p-1">
      <% if item.pictures.attached? %>
        <%= image_tag item.pictures.first, class: "w-10 h-10 object-cover border border-slate-200 rounded block" %>
      <% end %>
    </td>
    <td class="<%= style_table_td %> text-xs font-mono text-blue-600">
      <div><%= item.gencode %></div>
    </td>
    <td class="<%= style_table_td %>"><%= item.itemcode %></td>
    <td class="<%= style_table_td %>"><%= item.fabricode %></td>
    <td class="<%= style_table_td %>"><%= item.varcode %></td>
    <td class="<%= style_table_td %>"><%= item.description %></td>
    <td class="<%= style_table_td %> font-bold"><%= item.collection&.description&.upcase %></td>
  </tr>
</tbody>
```

- [ ] **Step 4: Add `new` action for pre-filled archive item creation**

The sidebar "Crea in archivio" button needs a `new` action that pre-fills the form from a mainware Item. Add this to `app/controllers/archive/items_controller.rb`:

```ruby
def new
  @item = Archive::Item.new
  if params[:from_item_id].present?
    source = Item.find_by(id: params[:from_item_id])
    if source
      @item.name = source.description.presence || source.gencode
      @item.description = source.description
      @item.notes = source.note
    end
  end
end
```

Also create `app/views/archive/items/new.html.erb` to render the form in a modal:

```erb
<%= turbo_frame_tag "item_modal" do %>
  <div class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center" data-controller="modal" data-action="keydown.esc->modal#close click->modal#backdropClose">
    <div class="bg-white dark:bg-slate-800 rounded-lg shadow-xl w-full max-w-lg mx-4 max-h-[90vh] overflow-y-auto">
      <div class="flex items-center justify-between p-4 border-b border-slate-200 dark:border-slate-600">
        <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-600 dark:text-slate-300">Nuovo articolo archivio</h2>
        <%= link_to archive_items_path, class: "text-slate-400 hover:text-slate-600 dark:hover:text-slate-200", data: { turbo_frame: "_top" } do %>
          <span class="material-symbols-outlined text-base">close</span>
        <% end %>
      </div>
      <div class="p-4">
        <div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-600 shadow-sm p-6">
          <%= render 'form', item: @item, turbo_frame: "item_modal" %>
        </div>
      </div>
    </div>
  </div>
<% end %>
```

- [ ] **Step 5: Add sidebar link**

Edit `app/views/layouts/menus/side/_structure.html.erb` — find the archive link and ensure it exists. Add the import link in the archive sidebar section:

```erb
<li>
  <%= link_to archive_items_path, class: "flex items-center gap-2 px-3 py-2 text-xs font-medium rounded-sm transition-colors #{active_if('archive/items')}" do %>
    <span class="material-symbols-outlined text-base">archive</span>
    Archivio
  <% end %>
</li>
<li>
  <%= link_to import_archive_items_path, class: "flex items-center gap-2 px-3 py-2 text-xs font-medium rounded-sm transition-colors #{active_if('archive/items/import')}" do %>
    <span class="material-symbols-outlined text-base">inventory_2</span>
    Importa da magazzino
  <% end %>
</li>
```

- [ ] **Step 6: Commit**

```bash
git add app/views/archive/items/import.html.erb app/views/archive/items/_import_item_row.html.erb app/views/archive/items/new.html.erb app/controllers/archive/items_controller.rb app/views/layouts/menus/side/_structure.html.erb
git commit -m "feat: add batch import page for warehouse-to-archive selection"
```

---

### Task 5: Scarica (Itemout) from selected items

**Files:**
- Modify: `app/controllers/archive/items_controller.rb`

- [ ] **Step 1: Add `import_itemout` action**

Edit `app/controllers/archive/items_controller.rb` — add the action:

```ruby
def import_itemout
  selected = params[:selected] || []
  return redirect_to import_archive_items_path, alert: "Nessun articolo selezionato" if selected.empty?

  session[:archive_itemout_prefill] = selected.map { |s|
    s.permit(:item_id, :gencode, :collection_id, :qty).to_h
  }
  redirect_to new_itemout_path, notice: "#{selected.size} articoli pronti per lo scarico."
end
```

- [ ] **Step 2: Verify route**

```bash
bin/rails routes | grep import_itemout
# Expected: POST /archive/items/import_itemout(.:format) archive/items#import_itemout
```

- [ ] **Step 3: Commit**

```bash
git add app/controllers/archive/items_controller.rb
git commit -m "feat: add import_itemout action for batch scarico from archive"
```

---

### Task 6: Import confirm — create Archive::Items

**Files:**
- Modify: `app/controllers/archive/items_controller.rb`
- Create: `app/views/archive/items/import_confirm.html.erb` (or handle inline)

- [ ] **Step 1: Add `import_confirm` action**

Edit `app/controllers/archive/items_controller.rb` — add the action:

```ruby
def import_confirm
  selected = params[:selected] || []
  return redirect_to import_archive_items_path, alert: "Nessun articolo selezionato" if selected.empty?

  created = []
  errors = []

  selected.each do |s|
    item = Item.find_by(id: s[:item_id])
    next unless item

    archive_item = Archive::Item.new(
      name: item.description.presence || item.gencode,
      description: item.description,
      notes: item.note,
      status: "in"
    )

    if archive_item.save
      if item.pictures.attached?
        item.pictures.each { |pic| archive_item.pictures.attach(pic.blob) }
      end

      if s[:inventory_id].present?
        archive_item.update_column(:inventory_id, s[:inventory_id])
      end

      created << archive_item.code
    else
      errors << "#{item.gencode}: #{archive_item.errors.full_messages.join(", ")}"
    end
  end

  if errors.any?
    redirect_to import_archive_items_path, alert: "Creati #{created.size}, errori: #{errors.join("; ")}"
  else
    redirect_to archive_items_path, notice: "#{created.size} articoli importati in archivio: #{created.join(", ")}"
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/controllers/archive/items_controller.rb
git commit -m "feat: add import_confirm action to create Archive::Items from warehouse selection"
```

---

### Task 7: Pre-fill Itemout from archive session data

**Files:**
- Modify: `app/controllers/itemouts_controller.rb`

- [ ] **Step 1: Pre-fill itemout new form from session**

Edit `app/controllers/itemouts_controller.rb` — in the `new` action, after the existing logic, check for `session[:archive_itemout_prefill]`:

```ruby
def new
  if session[:itemout_preview].present?
    @itemout = Itemout.new
    details = session[:itemout_preview]["itemouts_details_attributes"] || {}
    details.each_value { |d| @itemout.itemouts_details.build(d.except("id")) }
    session.delete(:itemout_preview)
  elsif session[:archive_itemout_prefill].present?
    @itemout = Itemout.new(indate: Date.current, operator: current_user)
    session[:archive_itemout_prefill].each do |data|
      @itemout.itemouts_details.build(
        itemcode: data["gencode"],
        item_id: data["item_id"],
        collection_id: data["collection_id"],
        qty: data["qty"] || 1,
        operationtype_id: 2
      )
    end
    session.delete(:archive_itemout_prefill)
  else
    @itemout = Itemout.new(indate: Date.current)
  end

  @warehouses = Warehouse.order(:code)
  @locations = Location.joins(:warehouse).order(:code)
  @operationtypes = Operationtype.all
end
```

- [ ] **Step 2: Commit**

```bash
git add app/controllers/itemouts_controller.rb
git commit -m "feat: pre-fill itemout form from archive import session data"
```
