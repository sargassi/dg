import { BrowserQRCodeReader } from "https://cdn.jsdelivr.net/npm/@zxing/library@0.21.3/+esm";
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["overlay", "video", "button"];

  connect() {
    this.codeReader = new BrowserQRCodeReader();
    this.targetInput = null;
    this.scanning = false;
  }

  scan(event) {
    const wrapper = event.currentTarget.closest("[data-row-qr-target='input']");
    this.targetInput = wrapper ? wrapper.querySelector("input[type='text']") : null;
    if (!this.targetInput) {
      this.targetInput = event.currentTarget.parentElement.querySelector("input[type='text']");
    }
    this.overlayTarget.classList.remove("hidden");
    this.buttonTarget.disabled = true;
    this.scanning = true;
    this._scan();
  }

  async _scan() {
    try {
      const result = await this.codeReader.decodeFromInputVideoDevice(undefined, this.videoTarget.id);
      if (!this.scanning) return;
      if (this.targetInput) {
        this.targetInput.value = result.text;
        this.targetInput.dispatchEvent(new Event("input", { bubbles: true }));
      }
    } catch (err) {
      if (this.scanning) console.error(err);
    } finally {
      if (this.scanning) this.stop();
    }
  }

  stop() {
    this.scanning = false;
    this.overlayTarget.classList.add("hidden");
    this.buttonTarget.disabled = false;
    this.targetInput = null;
    if (this.codeReader) {
      this.codeReader.reset();
    }
  }

  disconnect() {
    this.stop();
  }
}
