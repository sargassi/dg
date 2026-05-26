import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "hidden", "results", "collectionId", "collectionName"];
  static values = { url: String, minLength: { type: Number, default: 2 }, delay: { type: Number, default: 200 } };

  connect() {
    this.timeout = null;
    this.selected = false;
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
      fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
        headers: { Accept: "application/json" }
      })
        .then(r => r.json())
        .then(data => this.showResults(data));
    }, this.delayValue);
  }

  showResults(data) {
    if (data.length === 0) {
      this.resultsTarget.classList.add("hidden");
      this.resultsTarget.innerHTML = "";
      return;
    }

    const q = this.inputTarget.value.trim();
    const re = q ? new RegExp(`(${this._escapeRegExp(q)})`, "gi") : null;

    this.resultsTarget.innerHTML = data.map(item => {
      const label = re ? item.label.replace(re, '<mark class="bg-yellow-200 rounded px-0.5">$1</mark>') : this._escape(item.label);
      return `<li role="option" data-autocomplete-id="${item.id}" data-autocomplete-label="${item.gencode}" data-collection-id="${item.collection_id || ''}" data-collection-name="${this._escape(item.collection || '')}" class="px-3 py-2 text-xs cursor-pointer hover:bg-accent-50 border-b border-slate-100 last:border-0 flex justify-between items-center gap-4">
        <span>${label}</span>
        ${item.collection ? `<span class="font-bold text-slate-600 whitespace-nowrap">${this._escape(item.collection)}</span>` : ''}
      </li>`;
    }).join("");

    this.resultsTarget.querySelectorAll("li").forEach(li => {
      li.addEventListener("click", () => this.select(li));
    });

    this.resultsTarget.classList.remove("hidden");
  }

  select(li) {
    this.inputTarget.value = li.dataset.autocompleteLabel;
    this.hiddenTarget.value = li.dataset.autocompleteId;
    if (this.hasCollectionIdTarget) this.collectionIdTarget.value = li.dataset.collectionId || "";
    if (this.hasCollectionNameTarget) this.collectionNameTarget.textContent = li.dataset.collectionName || "";
    this.resultsTarget.classList.add("hidden");
    this.resultsTarget.innerHTML = "";
    this.selected = true;
  }

  hideResults() {
    setTimeout(() => {
      this.resultsTarget.classList.add("hidden");
    }, 200);
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