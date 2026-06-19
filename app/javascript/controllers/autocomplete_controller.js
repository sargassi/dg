import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "hidden", "results", "collectionId", "collectionName"];
  static values = { url: String, minLength: { type: Number, default: 2 }, delay: { type: Number, default: 200 } };

  connect() {
    this.timeout = null;
    this.selected = false;
    this._boundReposition = this._reposition.bind(this);
  }

  disconnect() {
    document.removeEventListener("scroll", this._boundReposition, true);
    window.removeEventListener("resize", this._boundReposition);
  }

  search() {
    clearTimeout(this.timeout);
    const q = this.inputTarget.value.trim();

    if (this.selected) {
      this.selected = false;
      return;
    }

    if (q.length < this.minLengthValue) {
      this.resultsTarget.classList.add("hidden");
      this.resultsTarget.innerHTML = "";
      return;
    }

    this.timeout = setTimeout(() => {
      let url = `${this.urlValue}?q=${encodeURIComponent(q)}`;
      const section = this.element.closest("[data-controller='defaults']");
      const collectionSelect = section?.querySelector('select[name="default_collection_id"]')
        || this.element.closest("form")?.querySelector('select[name="default_collection_id"]');
      if (collectionSelect?.value) url += `&collection_id=${collectionSelect.value}`;
      const daSection = this.element.closest("form")?.querySelector("[data-defaults-target-prefix='da']");
      if (daSection) {
        const whVal = daSection.querySelector("[data-defaults-target='warehouse']")?.value;
        const locVal = daSection.querySelector("[data-defaults-target='location']")?.value;
        if (whVal) url += `&warehouse_id=${whVal}`;
        if (locVal) url += `&location_id=${locVal}`;
      }
      fetch(url, {
        headers: { Accept: "application/json" }
      })
        .then(r => r.json())
        .then(data => this.showResults(data));
    }, this.delayValue);
  }

  showResults(data) {
    if (data.length === 0) {
      this.resultsTarget.innerHTML = '<li class="px-3 py-2 text-xs text-slate-400 italic">nessuna voce in questa posizione</li>';
      this.resultsTarget.classList.remove("hidden");
      document.removeEventListener("scroll", this._boundReposition, true);
      window.removeEventListener("resize", this._boundReposition);
      this.resultsTarget.style.position = "fixed";
      this.resultsTarget.style.zIndex = "9999";
      this.resultsTarget.classList.remove("absolute", "left-0", "right-0", "top-full", "mt-0.5");
      this._position();
      document.addEventListener("scroll", this._boundReposition, true);
      window.addEventListener("resize", this._boundReposition);
      return;
    }

    const q = this.inputTarget.value.trim();
    const re = q ? new RegExp(`(${this._escapeRegExp(q)})`, "gi") : null;

    const hideQty = this.element.closest("[data-autocomplete-hide-qty]");

    this.resultsTarget.innerHTML = data.map(item => {
      if (item.isHeader) {
        return `<li role="presentation" class="px-3 py-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500 bg-slate-100 border-b border-slate-200 pointer-events-none select-none">${this._escape(item.label)}</li>`;
      }
      const label = re ? item.label.replace(re, '<mark class="bg-yellow-200 rounded px-0.5">$1</mark>') : this._escape(item.label);
      const noStock = item.qty_remaining <= 0;
      const qtyClass = noStock ? 'text-red-500' : 'text-green-700';
      return `<li role="option" data-autocomplete-id="${item.id}" data-autocomplete-label="${item.itemcode}${item.fabricode}${item.varcode}" data-warehouse-id="${item.warehouse_id || ''}" data-location-id="${item.location_id || ''}" data-warehouse-code="${item.warehouse_code || ''}" data-location-code="${item.location_code || ''}" data-collection-id="${item.collection_id || ''}" data-collection-name="${this._escape(item.collection || '')}" data-qty-remaining="${item.qty_remaining}" class="px-3 py-2 text-xs ${noStock ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer hover:bg-accent-50'} border-b border-slate-100 last:border-0 flex justify-between items-center gap-4">
        <div class="flex flex-col gap-0.5 min-w-0">
          <span class="flex items-center gap-2">${label}${hideQty ? '' : `<span class="text-[10px] font-mono ${qtyClass}">${item.qty_remaining} pz</span>`}</span>
          <span class="text-[10px] text-slate-400 font-mono">${this._escape(item.warehouse_code || '')}${item.location_code ? ' / ' + this._escape(item.location_code) : ''}</span>
        </div>
        ${item.collection ? `<span class="font-bold text-slate-600 whitespace-nowrap">${this._escape(item.collection)}</span>` : ''}
      </li>`;
    }).join("");

    this.resultsTarget.querySelectorAll("li[data-qty-remaining]").forEach(li => {
      if (parseInt(li.dataset.qtyRemaining, 10) <= 0) return;
      li.addEventListener("click", () => this.select(li));
    });

    document.removeEventListener("scroll", this._boundReposition, true);
    window.removeEventListener("resize", this._boundReposition);
    this.resultsTarget.style.position = "fixed";
    this.resultsTarget.style.zIndex = "9999";
    this.resultsTarget.classList.remove("hidden");
    this.resultsTarget.classList.remove("absolute", "left-0", "right-0", "top-full", "mt-0.5");
    this._position();
    document.addEventListener("scroll", this._boundReposition, true);
    window.addEventListener("resize", this._boundReposition);
  }

  _position() {
    const rect = this.inputTarget.getBoundingClientRect();
    this.resultsTarget.style.top = `${rect.bottom + 4}px`;
    this.resultsTarget.style.left = `${rect.left}px`;
    this.resultsTarget.style.width = `${rect.width}px`;
  }

  _reposition() {
    if (!this.resultsTarget.classList.contains("hidden")) {
      this._position();
    }
  }

  select(li) {
    this.inputTarget.value = li.dataset.autocompleteLabel;
    this.hiddenTarget.value = li.dataset.autocompleteId;
    if (this.hasCollectionIdTarget) this.collectionIdTarget.value = li.dataset.collectionId || "";
    if (this.hasCollectionNameTarget) this.collectionNameTarget.textContent = li.dataset.collectionName || "";

    const row = li.closest("[data-nested-form-target='row']");
    if (row) {
      const whSelect = row.querySelector("select[name*='warehouse_id']");
      const locSelect = row.querySelector("select[name*='location_id']");
      const whHidden = row.querySelector("input[type='hidden'][name*='warehouse_id']");
      const locHidden = row.querySelector("input[type='hidden'][name*='location_id']");
      const whDisplay = row.querySelector(".wh-display");
      const locDisplay = row.querySelector(".loc-display");
      if (whSelect && li.dataset.warehouseId) whSelect.value = li.dataset.warehouseId;
      if (locSelect && li.dataset.locationId) locSelect.value = li.dataset.locationId;
      if (whHidden && li.dataset.warehouseId) whHidden.value = li.dataset.warehouseId;
      if (locHidden && li.dataset.locationId) locHidden.value = li.dataset.locationId;
      if (whDisplay && li.dataset.warehouseCode) whDisplay.textContent = li.dataset.warehouseCode;
      if (locDisplay && li.dataset.locationCode) locDisplay.textContent = li.dataset.locationCode;
      const selWh = row.querySelector(".selected-wh-display");
      const selLoc = row.querySelector(".selected-loc-display");
      if (selWh) selWh.textContent = li.dataset.warehouseCode || "—";
      if (selLoc) selLoc.textContent = li.dataset.locationCode || "—";
    }

    const qtyInput = row && row.querySelector("[name*='[qty]']");
    if (qtyInput && li.dataset.qtyRemaining) {
      qtyInput.max = parseInt(li.dataset.qtyRemaining, 10);
      qtyInput.dataset.maxQty = li.dataset.qtyRemaining;
      if (!qtyInput._qtyValidation) {
        qtyInput._qtyValidation = true;
        qtyInput.addEventListener("input", function () {
          const max = parseInt(this.dataset.maxQty, 10);
          if (max && parseInt(this.value, 10) > max) {
            this.setCustomValidity(`La quantità non può superare ${max} pz disponibili`);
          } else {
            this.setCustomValidity("");
          }
        });
      }
    }

    this._hideList();
    this.selected = true;
  }

  hideResults() {
    setTimeout(() => {
      this._hideList();
    }, 200);
  }

  _hideList() {
    this.resultsTarget.classList.add("hidden");
    this.resultsTarget.style.position = "";
    this.resultsTarget.style.top = "";
    this.resultsTarget.style.left = "";
    this.resultsTarget.style.width = "";
    document.removeEventListener("scroll", this._boundReposition, true);
    window.removeEventListener("resize", this._boundReposition);
  }

  _escape(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  _escapeRegExp(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }
}