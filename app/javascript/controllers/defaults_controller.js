import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["warehouse", "location"];

  connect() {
    this._cacheLocations();
    if (this.hasWarehouseTarget) {
      this.warehouseTarget.addEventListener("change", () => this._onWarehouseChange());
      this._onWarehouseChange();
    }

  }

  _cacheLocations() {
    if (!this.hasLocationTarget) return;
    this._allLocations = [];
    Array.from(this.locationTarget.options).forEach(opt => {
      if (opt.value) {
        this._allLocations.push({ id: opt.value, code: opt.text, warehouse_id: opt.dataset.warehouseId || "" });
      }
    });
  }

  _onWarehouseChange() {
    const whVal = this.hasWarehouseTarget ? this.warehouseTarget.value : "";
    if (!whVal) {
      this.locationTarget.disabled = true;
      this.locationTarget.innerHTML = '<option value="">Seleziona prima il magazzino</option>';
      this.propagate();
      return;
    }
    this.locationTarget.disabled = false;
    const filtered = this._allLocations.filter(l => l.warehouse_id === whVal);
    const defaultLoc = this.locationTarget.dataset.defaultLocation;
    delete this.locationTarget.dataset.defaultLocation;
    this.locationTarget.innerHTML = '<option value="">Seleziona ubica</option>' +
      filtered.map(l => `<option value="${l.id}" ${l.id === defaultLoc ? 'selected' : ''}>${l.code}</option>`).join("");
    this.propagate();
  }

  whText() {
    if (!this.hasWarehouseTarget) return "";
    const sel = this.warehouseTarget.selectedOptions[0];
    return sel && sel.value ? sel.text : "";
  }

  locText() {
    if (!this.hasLocationTarget) return "";
    const sel = this.locationTarget.selectedOptions[0];
    return sel && sel.value ? sel.text : "";
  }

  propagate() {
    const whVal = this.hasWarehouseTarget ? this.warehouseTarget.value : "";
    const locVal = this.hasLocationTarget ? this.locationTarget.value : "";
    const whTxt = this.whText();
    const locTxt = this.locText();
    const skipHidden = this.data.get("skip-propagate") !== undefined;
    const form = this.element.closest("form") || this.element;
    const rows = form.querySelectorAll("[data-nested-form-target='row']");

    rows.forEach(row => {
      if (!skipHidden) {
        const whHidden = row.querySelector("input[type='hidden'][name*='warehouse_id']");
        const locHidden = row.querySelector("input[type='hidden'][name*='location_id']");
        if (whHidden) whHidden.value = whVal;
        if (locHidden) locHidden.value = locVal;
        const whSpan = row.querySelector(".wh-display");
        const locSpan = row.querySelector(".loc-display");
        if (whSpan) whSpan.textContent = whTxt ? `Mag: ${whTxt}` : "—";
        if (locSpan) locSpan.textContent = locTxt ? `Ubi: ${locTxt}` : "—";
      }
    });
  }
}
