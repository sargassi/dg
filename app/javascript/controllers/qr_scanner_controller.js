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

  async _scan() {
    try {
      const result = await this.codeReader.decodeFromInputVideoDevice(undefined, this.videoTarget.id);
      const target = this.pendingInput || this.inputTarget;
      if (target) {
        target.value = result.text;
        target.dispatchEvent(new Event("input", { bubbles: true }));
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
