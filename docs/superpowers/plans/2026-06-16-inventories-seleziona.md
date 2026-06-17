# Seleziona Articoli per Carico — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `seleziona` action under InventoriesController that lets users browse/search items across all collections, select them via checkboxes into a fixed basket bar, then proceed to `app/in_warehouse` with items pre-filled.

**Architecture:** Use session-based data sharing between `seleziona` and `app/in_warehouse` — same pattern as `IteminsController` preview flow. A Stimulus controller manages the client-side basket. Server-side, `session[:carico_prefill]` stores selected items, read by `AppController#in_warehouse` on GET.

**Tech Stack:** Rails 7 + Hotwire (Turbo, Stimulus) + Pagy + TailwindCSS

**Design doc:** `docs/superpowers/specs/2026-06-16-inventories-seleziona-design.md`

---

### Task 1: Routes + Controller actions

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/inventories_controller.rb`

- [x] **Add routes**

Add after the existing `inventories/dashboard` route:

```ruby
  get 'inventories/seleziona'
  post 'inventories/seleziona/prepare_carico', to: 'inventories#prepare_carico', as: :inventories_prepare_carico
```

- [x] **Add seleziona action**

In `app/controllers/inventories_controller.rb`, add before `def import`:

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

  def prepare_carico
    selected = params[:selected] || []
    session[:carico_prefill] = selected.map { |s| s.permit(:item_id, :gencode, :collection_id, :qty).to_h }
    redirect_to app_in_warehouse_path, notice: "#{selected.size} articoli pronti per il carico."
  end
```

---

### Task 2: seleziona.html.erb view

**Files:**
- Create: `app/views/inventories/seleziona.html.erb`

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

<section class="<%= style_main_cnt %> flex flex-col" style="height: calc(100vh - 110px); padding-top: 5rem;" data-controller="seleziona search-filter">
  <%# Fixed basket bar %>
  <div data-seleziona-target="basket"
       class="hidden fixed top-0 left-0 right-0 z-40 bg-white border-b-2 border-accent shadow-lg px-4 py-2 ml-16"
       style="margin-top: 0;">
    <div class="flex items-center gap-4">
      <span class="material-symbols-outlined text-accent">shopping_cart</span>
      <span class="text-sm font-semibold text-slate-700" data-seleziona-target="basketCount">0 articoli selezionati</span>
      <div class="flex-1 flex items-center gap-2 overflow-x-auto" data-seleziona-target="basketItems">
      </div>
      <%= form_tag inventories_prepare_carico_path, method: :post, data: { seleziona_target: "form" } do %>
        <div data-seleziona-target="hiddenInputs"></div>
        <button type="submit" class="px-4 py-2 text-sm tracking-wide text-white rounded-sm bg-accent hover:bg-accent/90 font-medium whitespace-nowrap">
          Vai a Carico →
        </button>
      <% end %>
    </div>
  </div>

  <%# Search bar %>
  <div class="flex gap-4 items-center mb-4 flex-none">
    <%= form_with url: inventories_seleziona_path, method: :get,
                  data: { search_filter_target: "form", turbo_frame: "items-table" },
                  class: "flex items-center gap-3" do |f| %>
      <div class="relative">
        <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-base pointer-events-none">search</span>
        <%= f.search_field :q,
              value: params[:q],
              placeholder: "Cerca in tutte le colonne",
              class: "#{style_search_input} rounded-lg pl-10 font-mono text-blue-600",
              data: { action: "input->search-filter#filter", search_filter_target: "input" } %>
      </div>
      <%= f.collection_select :collection_id, @collections, :id, :description,
            { include_blank: "Tutte le collezioni", selected: params[:collection_id] },
            class: "border border-accent-100 outline-none p-2 text-xs bg-white rounded-lg shadow-sm w-40",
            data: { search_filter_target: "select", action: "change->search-filter#filter" } %>
    <% end %>
    <span class="text-sm font-bold text-slate-700 whitespace-nowrap border border-slate-300 rounded-full px-3 py-1" data-search-filter-target="count"><%= @pagy.count %> articoli</span>
  </div>

  <style>
    turbo-frame#items-table[busy] .items-table-content { display: none; }
    turbo-frame#items-table[busy] .items-table-loader { display: flex; }
  </style>
  <%= turbo_frame_tag "items-table", class: "flex flex-col flex-1 min-h-0", data: { action: "turbo:frame-load->search-filter#onFrameLoad" } do %>
    <div class="items-table-content flex flex-col flex-1 min-h-0">
      <span hidden data-filtered-count><%= @pagy.count %></span>
      <div class="overflow-x-auto flex-1 min-h-0 overflow-y-auto">
        <table class="min-w-full">
          <thead>
            <tr>
              <th class="<%= style_table_th %> sticky top-0 z-10 w-10"></th>
              <% %w[Gencode Item Fabric Var Descrizione Tg Fabric Color Materiale Note Collezione].each do |h| %>
                <th class="<%= style_table_th %> sticky top-0 z-10"><%= h %></th>
              <% end %>
            </tr>
          </thead>
          <%= render partial: 'seleziona_item_row', collection: @itemz, as: :item %>
        </table>
      </div>

      <% if @pagy.pages > 1 %>
        <div class="flex-none flex items-center gap-0.5 justify-end pt-3 pb-1">
          <% if @pagy.prev %>
            <a href="<%= pagy_url_for(@pagy, @pagy.prev) %>"
               data-turbo-frame="items-table"
               class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm text-slate-700 hover:bg-slate-100 transition-colors">
              <span class="material-symbols-outlined text-base">chevron_left</span>
            </a>
          <% else %>
            <span class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm text-slate-300 pointer-events-none">
              <span class="material-symbols-outlined text-base">chevron_left</span>
            </span>
          <% end %>

          <% @pagy.series.each do |item| %>
            <% if item.is_a?(Integer) %>
              <a href="<%= pagy_url_for(@pagy, item) %>"
                 data-turbo-frame="items-table"
                 class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm text-slate-700 hover:bg-slate-100 transition-colors">
                <%= item %>
              </a>
            <% elsif item == :gap %>
              <span class="px-1 text-slate-400 text-xs">…</span>
            <% elsif item == @pagy.page %>
              <span class="inline-flex items-center justify-center min-w-[2rem] h-8 text-xs rounded-sm bg-accent text-white font-medium">
                <%= item %>
              </span>
            <% end %>
          <% end %>

          <% if @pagy.next %>
            <a href="<%= pagy_url_for(@pagy, @pagy.next) %>"
               data-turbo-frame="items-table"
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

    <div class="items-table-loader hidden justify-center items-center py-12">
      <svg class="animate-spin h-10 w-10 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <span class="ml-3 text-slate-600">Ricerca in corso...</span>
    </div>
  <% end %>
</section>
```

---

### Task 3: _seleziona_item_row.html.erb partial

**Files:**
- Create: `app/views/inventories/_seleziona_item_row.html.erb`

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
    <td class="<%= style_table_td %> text-xs font-mono text-blue-600">
      <div><%= item.itemcode %><%= item.fabricode %><%= item.varcode %></div>
    </td>
    <td class="<%= style_table_td %>"><%= item.itemcode %></td>
    <td class="<%= style_table_td %>"><%= item.fabricode %></td>
    <td class="<%= style_table_td %>"><%= item.varcode %></td>
    <td class="<%= style_table_td %>"><%= item.description %></td>
    <td class="<%= style_table_td %>"><%= item.tg %></td>
    <td class="<%= style_table_td %>"><%= item.fabric %></td>
    <td class="<%= style_table_td %>"><%= item.colour %></td>
    <td class="<%= style_table_td %>"><%= item.materiale %></td>
    <td class="<%= style_table_td %>"><%= item.note %></td>
    <td class="<%= style_table_td %> font-bold"><%= item.collection&.description&.upcase %></td>
  </tr>
</tbody>
```

---

### Task 4: seleziona_controller.js Stimulus controller

**Files:**
- Create: `app/javascript/controllers/seleziona_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "basket", "basketCount", "basketItems", "form", "hiddenInputs"];

  connect() {
    this.selected = [];
  }

  toggleItem(event) {
    const cb = event.currentTarget;
    const item = {
      id: cb.dataset.id,
      gencode: cb.dataset.gencode,
      collectionId: cb.dataset.collectionId,
      collection: cb.dataset.collection,
      itemcode: cb.dataset.itemcode,
      qty: 1
    };

    if (cb.checked) {
      this.selected.push(item);
    } else {
      this.selected = this.selected.filter(s => s.id !== item.id);
    }

    this.renderBasket();
  }

  removeItem(id) {
    this.selected = this.selected.filter(s => s.id !== id);
    const cb = this.checkboxTargets.find(c => c.dataset.id === id);
    if (cb) cb.checked = false;
    this.renderBasket();
  }

  updateQty(event) {
    const id = event.currentTarget.dataset.id;
    const item = this.selected.find(s => s.id === id);
    if (item) {
      item.qty = parseInt(event.currentTarget.value) || 1;
    }
  }

  renderBasket() {
    if (this.selected.length === 0) {
      this.basketTarget.classList.add("hidden");
      return;
    }

    this.basketTarget.classList.remove("hidden");
    this.basketCountTarget.textContent = `${this.selected.length} articoli selezionati`;

    this.basketItemsTarget.innerHTML = this.selected.map(item => `
      <div class="flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-sm px-3 py-1.5 whitespace-nowrap flex-shrink-0">
        <span class="text-xs font-mono text-blue-600 font-semibold">${this.escape(item.gencode)}</span>
        <span class="text-[10px] text-slate-400">${this.escape(item.collection || '')}</span>
        <label class="text-[10px] text-slate-500">qty:</label>
        <input type="number" value="${item.qty}" min="1"
               data-id="${item.id}"
               data-action="change->seleziona#updateQty"
               class="w-14 text-xs border border-slate-300 outline-none px-1 py-0.5 text-center rounded-sm">
        <button type="button"
                data-action="click->seleziona#removeItem"
                data-id="${item.id}"
                class="text-slate-400 hover:text-red-500 transition">
          <span class="material-symbols-outlined text-sm">close</span>
        </button>
      </div>
    `).join("");

    this.hiddenInputsTarget.innerHTML = this.selected.map(item => `
      <input type="hidden" name="selected[][item_id]" value="${item.id}">
      <input type="hidden" name="selected[][gencode]" value="${item.gencode}">
      <input type="hidden" name="selected[][collection_id]" value="${item.collectionId}">
      <input type="hidden" name="selected[][qty]" value="${item.qty}">
    `).join("");
  }

  escape(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
```

---

### Task 5: Modify AppController#in_warehouse for session pre-fill

**Files:**
- Modify: `app/controllers/app_controller.rb`

In the `in_warehouse` action, when GET request and `session[:carico_prefill]` is present:

```ruby
if request.post?
  # ... existing POST logic ...
else
  @itemin = Itemin.new(indate: Date.current)

  if session[:carico_prefill].present?
    prefill = session.delete(:carico_prefill)
    details = prefill.map { |s|
      item = Item.find_by(id: s["item_id"])
      {
        itemcode: item&.gencode || s["gencode"],
        item_id: s["item_id"],
        collection_id: s["collection_id"],
        qty: s["qty"] || 1,
        operationtype_id: 1
      }
    }
    @itemin.itemins_details.build(details)
    @default_collection_id = details.first["collection_id"] if details.first
  end

  @default_warehouse_id = @default_location_id = nil
  load_form_data
end
```

Actually, let me re-read the existing `in_warehouse` action more carefully. The GET path sets up the form:

```ruby
else
  @itemin = Itemin.new(indate: Date.current)
  @default_collection_id = @default_warehouse_id = @default_location_id = nil
  load_form_data
end
```

I need to add the pre-fill logic here. The `load_form_data` method loads `@warehouses`, `@locations`, `@collections`. Let me check it.

Also need to check what `load_form_data` does. Let me look at the app_controller.

---

### Task 6: Add Seleziona link to inventory dashboard

**Files:**
- Modify: `app/views/inventories/dashboard.html.erb`

Add a "Seleziona" tile in the Magazzino card section:

```erb
<%= link_to inventories_seleziona_path, class: style_main_card_link do %>
  <span class="text-sm text-slate-700">Seleziona Articoli</span>
  <span class="material-symbols-outlined text-slate-300 text-base">checklist</span>
<% end %>
```

Add it after the "Nuovo Articolo" link and before the "Importa da Excel" link.
