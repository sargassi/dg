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
    this._savedLocationValue = this.locationTarget.value;
    Array.from(this.locationTarget.options).forEach(opt => {
      if (opt.value) {
        this._allLocations.push({ id: opt.value, code: opt.text, warehouse_id: opt.dataset.warehouseId || "" });
      }
    });
  }

  _setLocationOptions(filtered, selectedVal) {
    this.locationTarget.innerHTML = '<option value="">Tutte le ubiche</option>' +
      filtered.map(l => `<option value="${l.id}" ${l.id === selectedVal ? 'selected' : ''}>${l.code}</option>`).join("");
  }

  _onWarehouseChange() {
    const whVal = this.hasWarehouseTarget ? this.warehouseTarget.value : "";

    if (!whVal) {
      this.locationTarget.disabled = true;
      this.locationTarget.innerHTML = '<option value="">-</option>';
      return;
    }

    this.locationTarget.disabled = false;

    const filtered = this._allLocations.filter(l => l.warehouse_id === whVal);
    const selectedVal = filtered.some(l => l.id === this._savedLocationValue) ? this._savedLocationValue : "";
    this._savedLocationValue = "";
    this._setLocationOptions(filtered, selectedVal);
  }
}
