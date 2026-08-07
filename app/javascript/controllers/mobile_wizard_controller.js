import { BrowserQRCodeReader } from "https://cdn.jsdelivr.net/npm/@zxing/library@0.21.3/+esm";
import { Controller } from "@hotwired/stimulus";
import { playScanSound } from "scan_sound";

export default class extends Controller {
  static targets = ["step", "scanInput", "cart", "rows", "template", "overlay", "video", "progress", "scanCount", "doneBtn", "overlayList"];
  static values = {
    operationType: Number,
    scanUrl: String,
    whSelect: String,
    locSelect: String,
    autoPrompt: { type: Boolean, default: true }
  };

  connect() {
    this.codeReader = new BrowserQRCodeReader();
    this._scanning = false;
    this._stepIndex = 0;
    this._boundChange = (e) => this._onSelectChange(e);
    this.element.addEventListener("change", this._boundChange);
    this._goto(this._stepIndex);
  }

  disconnect() {
    this.stopScan();
    this.element.removeEventListener("change", this._boundChange);
  }

  // ---- Step navigation ----

  next(event) {
    if (event) event.preventDefault();
    if (!this._validateCurrentStep()) return;
    if (this._stepIndex < this._steps().length - 1) {
      this._goto(this._stepIndex + 1);
    }
  }

  back(event) {
    if (event) event.preventDefault();
    this._clearStepErrors();
    if (this._stepIndex > 0) {
      this._goto(this._stepIndex - 1);
    }
  }

  // Block submission if no article has been added to the cart. If the user
  // typed a code in the input without picking an autocomplete suggestion,
  // resolve it through the lookup endpoint and add it first.
  async submit(event) {
    if (this.cartTarget.children.length > 0) return;

    if (this.hasScanInputTarget && this.scanInputTarget.value.trim()) {
      if (event) event.preventDefault();
      await this._resolveCode(this.scanInputTarget.value.trim());
      if (this.cartTarget.children.length > 0) {
        this._submitForm();
        return;
      }
    }

    if (event) event.preventDefault();
    this._showSplash("Aggiungi almeno un articolo");
  }

  _submitForm() {
    const form = this.element.closest("form") || this.element;
    if (form && form.requestSubmit) {
      form.requestSubmit();
    } else if (form) {
      form.submit();
    }
  }

  async _resolveCode(text) {
    try {
      const resp = await fetch(`${this.scanUrlValue}?q=${encodeURIComponent(text)}`);
      const data = await resp.json();
      if (data.error || !data.item) return;
      const item = data.item;
      const pos = data.inbound || (data.positions && data.positions[0]) || null;
      this._addItem({
        id: item.id,
        label: `${item.itemcode}${item.fabricode}${item.varcode}`,
        gencode: item.gencode,
        description: item.description,
        qty_remaining: pos ? pos.net_qty : (data.qty_remaining || 0),
        collection_id: data.collection_id || item.collection_id || ""
      });
    } catch (err) {
      console.error(err);
    }
  }

  _steps() {
    return Array.from(this.stepTargets);
  }

  _validateCurrentStep() {
    const step = this._steps()[this._stepIndex];
    if (!step) return true;

    const whSelect = step.querySelector("select[name$='_warehouse_id']");
    if (whSelect && !whSelect.value) {
      this._markError(whSelect, "Seleziona il magazzino");
      return false;
    }
    return true;
  }

  _markError(select, message) {
    this._clearStepErrors();
    select.classList.add("border-red-500", "border-2");
    select.focus();
    this._showSplash(message);
    setTimeout(() => select.classList.remove("border-red-500", "border-2"), 2000);
  }

  _showSplash(message) {
    this._clearStepErrors();
    const splash = document.createElement("div");
    splash.dataset.mobileSplash = "true";
    splash.className = "fixed inset-0 z-[70] flex flex-col items-center justify-center bg-black/80 splash-in";
    splash.innerHTML = `
      <div class="bg-white dark:bg-slate-800 rounded-2xl w-[85%] max-w-sm px-6 py-10 text-center shadow-2xl">
        <span class="material-symbols-outlined text-7xl text-red-500 block mb-4">error</span>
        <p class="text-lg font-bold text-slate-800 dark:text-slate-100">${this._escape(message)}</p>
        <p class="text-sm text-slate-400 dark:text-slate-300 mt-2">Impossibile proseguire</p>
      </div>
    `;
    document.body.appendChild(splash);
    setTimeout(() => splash.remove(), 2000);
  }

  _clearStepErrors() {
    const step = this._steps()[this._stepIndex];
    if (!step) return;
    step.querySelectorAll(".border-red-500").forEach(el => el.classList.remove("border-red-500", "border-2"));
    step.querySelectorAll("p.text-red-600").forEach(el => el.remove());
    document.querySelectorAll("[data-mobile-splash]").forEach(el => el.remove());
  }

  _goto(index) {
    this._stepIndex = index;
    const steps = this._steps();
    steps.forEach((el, i) => {
      if (i < index) {
        // Past steps: keep visible but collapsed to a summary card.
        el.classList.remove("hidden");
        this._collapseStep(el);
      } else if (i === index) {
        // Current step: show the full controls.
        el.classList.remove("hidden");
        this._expandStep(el);
      } else {
        // Future steps: hidden.
        el.classList.add("hidden");
      }
    });
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `Passo ${index + 1} di ${steps.length}`;
    }
    this._autoPrompt();
  }

  // Auto-advance once a location step's Magazzino (and Ubica, when it has
  // locations) is selected. The completed step collapses into its summary.
  _onSelectChange(event) {
    const select = event.target;
    if (select.tagName !== "SELECT") return;
    const step = select.closest("[data-mobile-wizard-target='step']");
    if (!step || this._steps().indexOf(step) !== this._stepIndex) return;
    // Only auto-advance from location steps.
    if (!step.querySelector("select[name$='_warehouse_id']")) return;
    if (!this._stepComplete(step)) return;
    if (this._advanceTimer) clearTimeout(this._advanceTimer);
    this._advanceTimer = setTimeout(() => {
      this.next();
    }, 500);
  }

  _stepComplete(step) {
    const whSelect = step.querySelector("select[name$='_warehouse_id']");
    if (!whSelect || !whSelect.value) return false;
    const locSelect = step.querySelector("select[name$='_location_id']");
    // If the warehouse has locations, an Ubica is required to complete the step.
    if (locSelect && locSelect.options.length > 1 && !locSelect.value) return false;
    return true;
  }

  _collapseStep(step) {
    const controls = step.querySelector("[data-mobile-wizard-target='stepControls']");
    const summary = step.querySelector("[data-mobile-wizard-target='stepSummary']");
    if (!controls || !summary) return;
    this._fillSummary(step);
    controls.classList.add("hidden");
    summary.classList.remove("hidden");
  }

  _expandStep(step) {
    const controls = step.querySelector("[data-mobile-wizard-target='stepControls']");
    const summary = step.querySelector("[data-mobile-wizard-target='stepSummary']");
    if (controls) controls.classList.remove("hidden");
    if (summary) summary.classList.add("hidden");
  }

  _fillSummary(step) {
    const whSelect = step.querySelector("select[name$='_warehouse_id']");
    const locSelect = step.querySelector("select[name$='_location_id']");
    const whTxt = whSelect?.selectedOptions[0]?.text || "";
    const locTxt = locSelect?.selectedOptions[0]?.text || "";
    const whSpan = step.querySelector("[data-mobile-wizard-target='summaryWh']");
    const locSpan = step.querySelector("[data-mobile-wizard-target='summaryLoc']");
    if (whSpan) whSpan.textContent = whTxt;
    if (locSpan) locSpan.textContent = locTxt ? ` / ${locTxt}` : "";
  }

  // Reopen a previously completed step for editing.
  editStep(event) {
    const step = event.currentTarget.closest("[data-mobile-wizard-target='step']");
    const idx = this._steps().indexOf(step);
    if (idx >= 0) this._goto(idx);
  }

  // Auto-open the QR scan modal on location and items steps.
  _autoPrompt() {
    if (!this.autoPromptValue) return;
    const step = this._steps()[this._stepIndex];
    if (!step) return;
    const whSelect = step.querySelector("select[name$='_warehouse_id']");
    if (whSelect) {
      this._autoScanLocation(step, whSelect);
    } else {
      this._autoScanItem(step);
    }
  }

  // Auto-open the location QR scan when a location step has no warehouse selected.
  _autoScanLocation(step, whSelect) {
    if (whSelect.value) return;
    const scanBtn = step.querySelector("[data-action*='qr-scanner#scanWarehouseLoc']");
    if (!scanBtn) return;
    // Defer so the qr-scanner controller is connected before dispatching the click.
    setTimeout(() => scanBtn.click(), 100);
  }

  // Auto-open the item scan modal on the items step (unless items already added).
  _autoScanItem(step) {
    if (this.hasCartTarget && this.cartTarget.children.length > 0) return;
    const scanBtn = step.querySelector("[data-action*='mobile-wizard#startScan']");
    if (!scanBtn) return;
    setTimeout(() => scanBtn.click(), 100);
  }

  // Close the scan modal and focus the appropriate input for manual entry.
  manualSelect() {
    const step = this._steps()[this._stepIndex];
    if (!step) return;
    const whSelect = step.querySelector("select[name$='_warehouse_id']");
    if (whSelect) {
      whSelect.focus();
      whSelect.classList.add("ring-2", "ring-blue-400");
      setTimeout(() => whSelect.classList.remove("ring-2", "ring-blue-400"), 1500);
      return;
    }
    if (this.hasScanInputTarget) {
      this.scanInputTarget.focus();
    }
  }

  // ---- Scan-and-add cart ----

  addSelected(event) {
    const d = event.detail || {};
    this._addItem({
      id: d.id,
      label: d.label,
      gencode: d.gencode,
      description: d.description,
      qty_remaining: d.qty_remaining,
      collection_id: d.collection_id
    });
  }

  startScan(event) {
    if (event) event.preventDefault();
    this._scanning = true;
    this.overlayTarget.classList.remove("hidden");
    this._scan();
  }

  stopScan() {
    this._scanning = false;
    this.overlayTarget.classList.add("hidden");
    if (this.codeReader) {
      this.codeReader.reset();
    }
  }

  // "Fatto": close the item scan overlay and advance to the next step (A).
  finishScan(event) {
    if (event) event.preventDefault();
    this.stopScan();
    if (this._stepIndex < this._steps().length - 1) {
      this._goto(this._stepIndex + 1);
    }
  }

  // Continuous scanning: after each successful read the item is added to the
  // cart and the scanner immediately reads the next code. The modal stays open
  // until the user taps "Fatto" / close.
  async _scan() {
    if (!this._scanning) return;
    try {
      const result = await this.codeReader.decodeFromInputVideoDevice(undefined, this.videoTarget.id);
      const text = result.text;
      const resp = await fetch(`${this.scanUrlValue}?q=${encodeURIComponent(text)}`);
      const data = await resp.json();
      if (data.error || !data.item) {
        // Unknown code — keep scanning.
        this._scan();
        return;
      }
      const item = data.item;
      const pos = data.inbound || (data.positions && data.positions[0]) || null;
      this._addItem({
        id: item.id,
        label: `${item.itemcode}${item.fabricode}${item.varcode}`,
        gencode: item.gencode,
        description: item.description,
        qty_remaining: pos ? pos.net_qty : (data.qty_remaining || 0),
        collection_id: data.collection_id || item.collection_id || ""
      });
      playScanSound();
      // Keep scanning for the next code.
      setTimeout(() => this._scan(), 300);
    } catch (err) {
      // "Video stream has ended before any code could be detected" is thrown
      // when the camera stream stops (overlay closed / stopped). Expected.
      if (err && typeof err.message === "string" && err.message.includes("Video stream has ended")) return;
      console.error(err);
      // Camera error — keep the modal open, let the user close or retry.
    }
  }

  _addItem(d) {
    if (!d.id) return;

    const existing = this._findRow(d.id);
    if (existing) {
      const qty = existing.querySelector("[name*='[qty]']");
      qty.value = (parseInt(qty.value, 10) || 1) + 1;
      this._syncCartLine(existing);
      this._resetScanInput();
      this._updateScanCount();
      return;
    }

    const stamp = new Date().getTime();
    const html = this.templateTarget.innerHTML.replace(/__NEW__/g, stamp);
    this.rowsTarget.insertAdjacentHTML("beforeend", html);
    const row = this.rowsTarget.lastElementChild;
    row.dataset.row = stamp;

    row.querySelector("[name*='[item_id]']").value = d.id;
    row.querySelector("[name*='[itemcode]']").value = d.label || d.gencode || "";
    row.querySelector("[name*='[operationtype_id]']").value = this.operationTypeValue;
    if (d.collection_id) {
      const coll = row.querySelector("[name*='[collection_id]']");
      if (coll) coll.value = d.collection_id;
    }

    const wh = this._selectedValue(this.whSelectValue);
    const loc = this._selectedValue(this.locSelectValue);
    const whInput = row.querySelector("[name*='[warehouse_id]']");
    const locInput = row.querySelector("[name*='[location_id]']");
    if (whInput && wh) whInput.value = wh;
    if (locInput && loc) locInput.value = loc;

    const qty = row.querySelector("[name*='[qty]']");
    qty.value = 1;
    if (d.qty_remaining) qty.max = parseInt(d.qty_remaining, 10);

    this._appendCartLine(row, d);
    this._resetScanInput();
    this._updateScanCount();
  }

  _updateScanCount() {
    const total = this.cartTarget.children.length;
    if (this.hasScanCountTarget) {
      this.scanCountTarget.textContent = `${total} ${total === 1 ? "articolo scansionato" : "articoli scansionati"}`;
    }
    if (this.hasDoneBtnTarget) {
      this.doneBtnTarget.classList.toggle("hidden", total === 0);
    }
  }

  inc(event) {
    this._adjustQty(event.currentTarget, 1);
  }

  dec(event) {
    this._adjustQty(event.currentTarget, -1);
  }

  remove(event) {
    const line = event.currentTarget.closest("[data-line]");
    if (!line) return;
    const id = line.dataset.line;
    const row = this.rowsTarget.querySelector(`[data-row='${id}']`);
    row?.remove();
    this.cartTarget.querySelector(`[data-line='${id}']`)?.remove();
    if (this.hasOverlayListTarget) {
      this.overlayListTarget.querySelector(`[data-line='${id}']`)?.remove();
    }
    this._updateScanCount();
  }

  _adjustQty(button, delta) {
    const line = button.closest("[data-line]");
    if (!line) return;
    const row = this.rowsTarget.querySelector(`[data-row='${line.dataset.line}']`);
    if (!row) return;
    const qty = row.querySelector("[name*='[qty]']");
    let value = (parseInt(qty.value, 10) || 0) + delta;
    if (qty.max && value > parseInt(qty.max, 10)) value = parseInt(qty.max, 10);
    if (value < 1) value = 1;
    qty.value = value;
    this._syncCartLine(row);
  }

  _syncCartLine(row) {
    const qty = row.querySelector("[name*='[qty]']");
    const update = (container) => {
      if (!container) return;
      const line = container.querySelector(`[data-line='${row.dataset.row}']`);
      const badge = line?.querySelector("[data-line-qty]");
      if (badge) badge.textContent = qty.value;
    };
    update(this.cartTarget);
    if (this.hasOverlayListTarget) update(this.overlayListTarget);
  }

  _findRow(id) {
    return this.rowsTarget.querySelector(`[name*='[item_id]'][value='${id}']`)?.closest("[data-row]") || null;
  }

  _appendCartLine(row, d) {
    const line = this._buildLineHtml(row, d);
    this.cartTarget.appendChild(line);
    if (this.hasOverlayListTarget) {
      const clone = this._buildLineHtml(row, d);
      this.overlayListTarget.appendChild(clone);
    }
  }

  _buildLineHtml(row, d) {
    const div = document.createElement("div");
    div.className = "flex items-center gap-3 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2";
    div.dataset.line = row.dataset.row;
    div.innerHTML = `
      <div class="flex-1 min-w-0">
        <div class="text-sm font-semibold text-slate-800 dark:text-slate-200 truncate">${this._escape(d.label || "")}</div>
        <div class="text-[11px] text-slate-400 dark:text-slate-300 truncate">${this._escape(d.description || d.gencode || "")}</div>
      </div>
      <div class="flex items-center gap-1 flex-shrink-0">
        <button type="button" data-action="mobile-wizard#dec" class="w-9 h-9 flex items-center justify-center rounded-full bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200 text-lg font-bold active:scale-95">−</button>
        <span data-line-qty class="min-w-7 text-center text-sm font-bold text-slate-800 dark:text-slate-200">1</span>
        <button type="button" data-action="mobile-wizard#inc" class="w-9 h-9 flex items-center justify-center rounded-full bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200 text-lg font-bold active:scale-95">+</button>
      </div>
      <button type="button" data-action="mobile-wizard#remove" class="w-9 h-9 flex items-center justify-center rounded-full text-red-500 hover:bg-red-50 dark:hover:bg-red-900/30">
        <span class="material-symbols-outlined text-base">delete</span>
      </button>
    `;
    return div;
  }

  _resetScanInput() {
    if (!this.hasScanInputTarget) return;
    this.scanInputTarget.value = "";
    this.scanInputTarget.focus();
  }

  _selectedValue(name) {
    const select = this.element.querySelector(`select[name='${name}']`);
    return select ? select.value : "";
  }

  _escape(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
