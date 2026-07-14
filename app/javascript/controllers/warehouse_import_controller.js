import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["info", "gencode", "description", "stock"];

  connect() {
    this.boundSelect = this._onSelect.bind(this);
    this.element.addEventListener("autocomplete:select", this.boundSelect);
  }

  disconnect() {
    this.element.removeEventListener("autocomplete:select", this.boundSelect);
  }

  _onSelect(event) {
    const { gencode, description, qty_remaining } = event.detail;
    this.gencodeTarget.textContent = gencode || "";
    this.descriptionTarget.textContent = description || "";
    const qty = parseInt(qty_remaining, 10) || 0;
    this.stockTarget.textContent = `${qty} pz`;
    this.stockTarget.classList.toggle("text-green-600", qty > 0);
    this.stockTarget.classList.toggle("text-red-500", qty <= 0);
    this.infoTarget.classList.remove("hidden");
  }
}
