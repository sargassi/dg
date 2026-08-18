import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["root", "panel"];

  connect() {
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close();
    };
    document.addEventListener("keydown", this._onKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown);
  }

  open() {
    this.rootTarget.classList.remove("hidden");
    requestAnimationFrame(() => {
      this.panelTarget.classList.remove("translate-x-full");
    });
  }

  close() {
    this.panelTarget.classList.add("translate-x-full");
    setTimeout(() => {
      this.rootTarget.classList.add("hidden");
    }, 300);
  }
}