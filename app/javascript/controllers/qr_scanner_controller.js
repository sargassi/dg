import { BrowserQRCodeReader } from "https://cdn.jsdelivr.net/npm/@zxing/library@0.21.3/+esm";
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "video", "overlay"];

  connect() {
    this.codeReader = new BrowserQRCodeReader();
    this.pendingInput = null;
  }

  scanRow(event) {
    const input = event.currentTarget.parentElement.querySelector("[data-qr-scanner-target='input']");
    this.pendingInput = input;
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
