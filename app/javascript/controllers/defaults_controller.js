import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";

export default class extends Controller {
  static targets = ["warehouse", "location", "collection"];

  connect() {
    this._cacheLocations();

    if (this.hasCollectionTarget) {
      this.tsCollection = this._initSelect(this.collectionTarget, {
        allowEmptyOption: true,
      });
    }

    this.tsWarehouse = this._initSelect(this.warehouseTarget, {
      allowEmptyOption: true,
      onChange: () => this._onWarehouseChange(),
    });

    this.tsLocation = this._initSelect(this.locationTarget, {
      allowEmptyOption: true,
      onChange: () => this.propagate(),
    });

    // Bridge: keep Tom Select in sync when a value is set programmatically
    // on the native select (e.g. QR scan sets value and dispatches change).
    this.warehouseTarget.addEventListener("change", () => {
      if (this.tsWarehouse) this.tsWarehouse.setValue(this.warehouseTarget.value, true);
      this._onWarehouseChange();
    });
    this.locationTarget.addEventListener("change", () => {
      if (this.tsLocation) this.tsLocation.setValue(this.locationTarget.value, true);
      this.propagate();
    });

    this._onWarehouseChange();
  }

  _initSelect(el, opts = {}) {
    if (!el) return null;
    const defaults = {
      render: {
        item: (data, escape) => (data.value ? `<div>${escape(data.text)}</div>` : "<div>...</div>"),
      },
    };
    return new TomSelect(el, { ...defaults, ...opts });
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
      if (this.tsLocation) {
        this.tsLocation.disable();
        this.tsLocation.clearOptions();
        this.tsLocation.setValue("", true);
        this.tsLocation.refreshOptions(false);
      }
      this.propagate();
      return;
    }
    this.locationTarget.disabled = false;
    if (this.tsLocation) {
      this.tsLocation.enable();
      this.tsLocation.clearOptions();
      const filtered = this._allLocations.filter(l => l.warehouse_id === whVal);
      this.tsLocation.addOption(filtered.map(l => ({ value: l.id, text: l.code })));
      const defaultLoc = this.locationTarget.dataset.defaultLocation;
      delete this.locationTarget.dataset.defaultLocation;
      this.tsLocation.setValue(defaultLoc || "", true);
      this.tsLocation.refreshOptions(false);
    }
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

    const whTxtVal = whTxt ? `Mag: ${whTxt}` : "—";
    const locTxtVal = locTxt ? `Ubi: ${locTxt}` : "—";
    rows.forEach(row => {
      if (!skipHidden) {
        const whHidden = row.querySelector("input[type='hidden'][name*='warehouse_id']");
        const locHidden = row.querySelector("input[type='hidden'][name*='location_id']");
        if (whHidden) whHidden.value = whVal;
        if (locHidden) locHidden.value = locVal;
      }
    });
    form.querySelectorAll(".wh-display").forEach(el => el.textContent = whTxtVal);
    form.querySelectorAll(".loc-display").forEach(el => el.textContent = locTxtVal);
  }

  disconnect() {
    if (this.tsCollection) {
      this.tsCollection.destroy();
      this.tsCollection = null;
    }
    if (this.tsWarehouse) {
      this.tsWarehouse.destroy();
      this.tsWarehouse = null;
    }
    if (this.tsLocation) {
      this.tsLocation.destroy();
      this.tsLocation = null;
    }
  }
}
