import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "results", "form"];
  static values = { url: String, minLength: { type: Number, default: 2 }, delay: { type: Number, default: 200 } };

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

    if (data.length === 1) {
      this._hideList();
      this._populateFormFromData(data[0]);
      return;
    }

    const q = this.inputTarget.value.trim();
    const re = q ? new RegExp(`(${this._escapeRegExp(q)})`, "gi") : null;

    this.resultsTarget.innerHTML = data.map(item => {
      const label = re ? item.label.replace(re, '<mark class="bg-yellow-200 rounded px-0.5">$1</mark>') : this._escape(item.label);
      return `<li role="option" data-clone-id="${item.id}" data-gencode="${item.gencode}" data-itemcode="${item.itemcode || ''}" data-fabricode="${item.fabricode || ''}" data-varcode="${item.varcode || ''}" data-description="${this._escape(item.description || '')}" data-tg="${item.tg || ''}" data-fabric="${this._escape(item.fabric || '')}" data-colour="${this._escape(item.colour || '')}" data-materiale="${this._escape(item.materiale || '')}" data-collection-id="${item.collection_id || ''}" class="px-3 py-2 text-xs cursor-pointer hover:bg-accent-50 border-b border-slate-100 last:border-0">
        <span class="flex items-center gap-2">${label}</span>
        ${item.collection ? `<span class="font-bold text-slate-600 whitespace-nowrap ml-2">${this._escape(item.collection)}</span>` : ''}
      </li>`;
    }).join("");

    this.resultsTarget.querySelectorAll("li[data-clone-id]").forEach(li => {
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
    this.inputTarget.value = li.dataset.gencode;
    this._populateForm(li);
    this._hideList();
    this.selected = true;
  }

  _populateForm(li) {
    const setValue = (name, value) => {
      const input = this.element.querySelector(`[name="item[${name}]"]`);
      if (input) input.value = value;
    };

    setValue("itemcode", li.dataset.itemcode);
    setValue("fabricode", li.dataset.fabricode);
    setValue("varcode", li.dataset.varcode);
    setValue("description", li.dataset.description);
    setValue("tg", li.dataset.tg);
    setValue("fabric", li.dataset.fabric);
    setValue("colour", li.dataset.colour);
    setValue("materiale", li.dataset.materiale);
  }

  _populateFormFromData(item) {
    const setValue = (name, value) => {
      const input = this.element.querySelector(`[name="item[${name}]"]`);
      if (input) input.value = value;
    };

    setValue("itemcode", item.itemcode || "");
    setValue("fabricode", item.fabricode || "");
    setValue("varcode", item.varcode || "");
    setValue("description", item.description || "");
    setValue("tg", item.tg || "");
    setValue("fabric", item.fabric || "");
    setValue("colour", item.colour || "");
    setValue("materiale", item.materiale || "");
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