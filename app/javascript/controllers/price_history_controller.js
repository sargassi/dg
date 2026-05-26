import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["detail", "colprice"];
  static values = { id: Number };

  connect() {
    this.open = false;
    const params = new URLSearchParams(window.location.search);
    if (params.get("expand_history") == String(this.idValue)) {
      this._expand();
    }
  }

  toggle() {
    if (this.open) {
      this._collapse();
    } else {
      this._expand();
    }
  }

  _expand() {
    this.open = true;
    this.detailTargets.forEach((el) => el.classList.remove("hidden"));
    this.colpriceTargets.forEach((el) => el.classList.add("bg-green-50"));
  }

  _collapse() {
    this.open = false;
    this.detailTargets.forEach((el) => el.classList.add("hidden"));
    this.colpriceTargets.forEach((el) => el.classList.remove("bg-green-50"));
  }
}
