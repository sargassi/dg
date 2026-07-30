import { BrowserQRCodeReader } from "https://cdn.jsdelivr.net/npm/@zxing/library@0.21.3/+esm";
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "video", "overlay"];

  connect() {
    this.codeReader = new BrowserQRCodeReader();
    this.pendingInput = null;
  }

  start(event) {
    if (event) event.preventDefault();
    this.overlayTarget.classList.remove("hidden");
    this._scan();
  }

  scanRow(event) {
    const input = event.currentTarget.parentElement.querySelector("[data-qr-scanner-target='input']");
    this.pendingInput = input;

    this._callback = async (text) => {
      input.value = text;
      input.dispatchEvent(new Event("input", { bubbles: true }));

      const row = input.closest("[data-nested-form-target='row']");
      if (!row) return;

      try {
        const resp = await fetch(`/inventories/lookup_by_qr?q=${encodeURIComponent(text)}`);
        const data = await resp.json();
        if (data.error) return;

        const itemIdHidden = row.querySelector("input[type='hidden'][name*='[item_id]']");
        const whHidden = row.querySelector("input[type='hidden'][name*='warehouse_id']");
        const locHidden = row.querySelector("input[type='hidden'][name*='location_id']");
        const selWh = row.querySelector(".selected-wh-display");
        const selLoc = row.querySelector(".selected-loc-display");

        if (itemIdHidden && data.item && data.item.id) {
          itemIdHidden.value = data.item.id;
          const collHidden = row.querySelector("input[type='hidden'][name*='collection_id']");
          if (collHidden && data.collection_id) collHidden.value = data.collection_id;
        }

        const pos = data.inbound || (data.positions && data.positions[0]);
        if (!pos) return;
        if (whHidden && pos.warehouse_id) whHidden.value = pos.warehouse_id;
        if (locHidden && pos.location_id) locHidden.value = pos.location_id;
        if (selWh) selWh.textContent = pos.warehouse || "—";
        if (selLoc) selLoc.textContent = pos.location || "—";
      } catch (e) {
        console.error("lookup_by_qr failed", e);
      }
    };

    this.overlayTarget.classList.remove("hidden");
    this._scan();
  }

  scanWarehouseLoc(event) {
    const section = event.currentTarget.closest("[data-controller='defaults']") || this.element.closest("[data-controller='defaults']");
    this._callback = async (text) => {
      const resp = await fetch(`/inventories/warehouses/lookup_by_qr?q=${encodeURIComponent(text)}`);
      const data = await resp.json();
      if (!section) return;
      const whSelect = section.querySelector("[data-defaults-target='warehouse']");
      const locSelect = section.querySelector("[data-defaults-target='location']");
      if (data.warehouse_id && whSelect) {
        whSelect.value = data.warehouse_id;
        whSelect.dispatchEvent(new Event("change", { bubbles: true }));
      }
      if (data.location_id && locSelect) {
        setTimeout(() => {
          locSelect.value = data.location_id;
          locSelect.dispatchEvent(new Event("change", { bubbles: true }));
        }, 50);
      }
    };
    this.overlayTarget.classList.remove("hidden");
    this._scan();
  }

  async _scan() {
    try {
      const result = await this.codeReader.decodeFromInputVideoDevice(undefined, this.videoTarget.id);
      if (this._callback) {
        await this._callback(result.text);
        this._callback = null;
      } else {
        const target = this.pendingInput || this.inputTarget;
        if (target) {
          target.value = result.text;
          target.dispatchEvent(new Event("input", { bubbles: true }));
        }
      }
    } catch (err) {
      console.error(err);
    } finally {
      this.stop();
    }
  }

  stop() {
    this.overlayTarget.classList.add("hidden");
    this.pendingInput = null;
    if (this.codeReader) {
      this.codeReader.reset();
    }
  }

  disconnect() {
    this.stop();
  }
}
