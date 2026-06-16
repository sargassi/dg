import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "results"];
  static values = { url: String, field: String, minLength: { type: Number, default: 1 }, delay: { type: Number, default: 200 } };

  connect() {
    this.timeout = null;
    this.selected = false;
    this._boundReposition = this._reposition.bind(this);
  }

  disconnect() {
    document.removeEventListener("scroll", this._boundReposition, true);
    window.removeEventListener("resize", this._boundReposition);
  }

  search() {
    clearTimeout(this.timeout);
    const q = this.inputTarget.value.trim();

    if (this.selected) {
      this.selected = false;
      return;
    }

    if (q.length < this.minLengthValue) {
      this.resultsTarget.classList.add("hidden");
      this.resultsTarget.innerHTML = "";
      return;
    }

    this.timeout = setTimeout(() => {
      const url = `${this.urlValue}?field=${encodeURIComponent(this.fieldValue)}&q=${encodeURIComponent(q)}`;
      fetch(url, {
        headers: { Accept: "application/json" }
      })
        .then(r => r.json())
        .then(data => this.showResults(data));
    }, this.delayValue);
  }

  showResults(data) {
    const q = this.inputTarget.value.trim().toLowerCase();

    if (data.length === 0) {
      this.resultsTarget.classList.add("hidden");
      this.resultsTarget.innerHTML = "";
      return;
    }

    const re = q ? new RegExp(`(${this._escapeRegExp(q)})`, "gi") : null;

    this.resultsTarget.innerHTML = data.map(value => {
      const label = re ? value.replace(re, '<mark class="bg-yellow-200 rounded px-0.5">$1</mark>') : this._escape(value);
      return `<li role="option" data-value="${this._escape(value)}" class="px-3 py-2 text-xs cursor-pointer hover:bg-accent-50 border-b border-slate-100 last:border-0 font-mono">${label}</li>`;
    }).join("");

    this.resultsTarget.querySelectorAll("li[data-value]").forEach(li => {
      li.addEventListener("click", () => this.select(li));
    });

    document.removeEventListener("scroll", this._boundReposition, true);
    window.removeEventListener("resize", this._boundReposition);
    this.resultsTarget.style.position = "fixed";
    this.resultsTarget.style.zIndex = "9999";
    this.resultsTarget.classList.remove("hidden");
    this.resultsTarget.classList.remove("absolute", "left-0", "right-0", "top-full", "mt-0.5");
    this._position();
    document.addEventListener("scroll", this._boundReposition, true);
    window.addEventListener("resize", this._boundReposition);
  }

  _position() {
    const rect = this.inputTarget.getBoundingClientRect();
    this.resultsTarget.style.top = `${rect.bottom + 4}px`;
    this.resultsTarget.style.left = `${rect.left}px`;
    this.resultsTarget.style.width = `${rect.width}px`;
  }

  _reposition() {
    if (!this.resultsTarget.classList.contains("hidden")) {
      this._position();
    }
  }

  select(li) {
    this.inputTarget.value = li.dataset.value;
    this._hideList();
    this.selected = true;
  }

  hideResults() {
    setTimeout(() => {
      this._hideList();
    }, 200);
  }

  _hideList() {
    this.resultsTarget.classList.add("hidden");
    this.resultsTarget.style.position = "";
    this.resultsTarget.style.top = "";
    this.resultsTarget.style.left = "";
    this.resultsTarget.style.width = "";
    document.removeEventListener("scroll", this._boundReposition, true);
    window.removeEventListener("resize", this._boundReposition);
  }

  _escape(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  _escapeRegExp(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }
}
