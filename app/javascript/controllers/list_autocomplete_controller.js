import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "results", "newForm", "newInput", "newResults", "newStatus", "useAnyway", "showAllBtn"];
  static values = {
    url: String,
    field: String,
    valueInfoUrl: String,
    minLength: { type: Number, default: 1 },
    delay: { type: Number, default: 200 }
  };

  connect() {
    this.timeout = null;
    this.selected = false;
    this.showAllMode = false;
    this._boundReposition = this._reposition.bind(this);
  }

  disconnect() {
    clearTimeout(this.timeout);
    document.removeEventListener("scroll", this._boundReposition, true);
    window.removeEventListener("resize", this._boundReposition);
  }

  // ---------- autocomplete ----------

  search() {
    clearTimeout(this.timeout);
    const q = this.inputTarget.value.trim();

    if (this.selected) {
      this.selected = false;
      return;
    }

    this.timeout = setTimeout(() => {
      const params = this._filterParams();
      params.set("field", this.fieldValue);
      params.set("q", q);
      if (!q) params.set("limit", "200");
      fetch(`${this.urlValue}?${params.toString()}`, {
        headers: { Accept: "application/json" }
      })
        .then(r => r.json())
        .then(data => this.showResults(data));
    }, this.delayValue);
  }

  _filterParams() {
    const params = new URLSearchParams();
    if (this.showAllMode) return params;
    if (this.fieldValue === "fabricode" || this.fieldValue === "varcode") {
      const itemcode = this._fieldValue("itemcode");
      if (itemcode) params.set("itemcode", itemcode);
    }
    if (this.fieldValue === "varcode") {
      const fabricode = this._fieldValue("fabricode");
      if (fabricode) params.set("fabricode", fabricode);
    }
    return params;
  }

  _fieldValue(field) {
    const form = this.element.closest("form");
    const wrapper = form
      ? form.querySelector(`[data-list-autocomplete-field-value="${field}"]`)
      : null;
    const input = wrapper ? wrapper.querySelector("input") : null;
    return input ? input.value.trim() : "";
  }

  showAll() {
    this.showAllMode = true;
    this._syncShowAllBtn();
    const q = this.inputTarget.value.trim();
    const params = new URLSearchParams({ field: this.fieldValue, q });
    params.set("limit", "200");
    fetch(`${this.urlValue}?${params.toString()}`, {
      headers: { Accept: "application/json" }
    })
      .then(r => r.json())
      .then(data => this.showResults(data));
  }

  _syncShowAllBtn() {
    if (!this.hasShowAllBtnTarget) return;
    this.showAllBtnTarget.classList.toggle("text-accent-700", this.showAllMode);
    this.showAllBtnTarget.classList.toggle("dark:text-accent-300", this.showAllMode);
  }

  preventBlur(event) {
    event.preventDefault();
  }

  showResults(data) {
    const q = this.inputTarget.value.trim().toLowerCase();

    if (data.length === 0) {
      this._hideList();
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
    this.showAllMode = false;
    this._syncShowAllBtn();
  }

  hideResults() {
    setTimeout(() => {
      this._hideList();
    }, 200);
  }

  _hideList() {
    this.resultsTarget.classList.add("hidden");
    this.resultsTarget.innerHTML = "";
    this.resultsTarget.style.position = "";
    this.resultsTarget.style.top = "";
    this.resultsTarget.style.left = "";
    this.resultsTarget.style.width = "";
    document.removeEventListener("scroll", this._boundReposition, true);
    window.removeEventListener("resize", this._boundReposition);
  }

  preventEnter(event) {
    event.preventDefault();
  }

  // ---------- create new ----------

  toggleNew() {
    this._resetNewStatus();
    this.newFormTarget.classList.remove("hidden");
    this.newFormTarget.classList.add("flex");
    this._hideNewResults();
    this.newInputTarget.focus();
  }

  cancelNew() {
    this.newFormTarget.classList.add("hidden");
    this.newFormTarget.classList.remove("flex");
    this._hideNewResults();
    this._resetNewStatus();
  }

  backdropClick(event) {
    if (event.target === event.currentTarget) this.cancelNew();
  }

  stop(event) {
    event.stopPropagation();
  }

  _resetNewStatus() {
    if (this.newInputTarget) this.newInputTarget.value = "";
    if (this.hasNewStatusTarget) {
      this.newStatusTarget.textContent = "";
      this.newStatusTarget.classList.add("hidden");
    }
    if (this.hasUseAnywayTarget) this.useAnywayTarget.classList.add("hidden");
  }

  searchNew() {
    clearTimeout(this.timeout);
    const q = this.newInputTarget.value.trim();
    if (q.length < 1) {
      this._hideNewResults();
      return;
    }
    this.timeout = setTimeout(() => {
      const params = new URLSearchParams({ field: this.fieldValue, q });
      params.set("limit", "20");
      fetch(`${this.urlValue}?${params.toString()}`, {
        headers: { Accept: "application/json" }
      })
        .then(r => r.json())
        .then(data => this._renderNewResults(data));
    }, this.delayValue);
  }

  _renderNewResults(data) {
    if (!data || data.length === 0) {
      this._hideNewResults();
      return;
    }
    this.newResultsTarget.innerHTML = data.map(value =>
      `<li role="option" data-value="${this._escape(value)}" class="px-3 py-2 text-xs cursor-pointer hover:bg-accent-50 border-b border-slate-100 last:border-0 font-mono">${this._escape(value)}</li>`
    ).join("");
    this.newResultsTarget.classList.remove("hidden");
    this.newResultsTarget.querySelectorAll("li[data-value]").forEach(li => {
      li.addEventListener("click", () => {
        this.newInputTarget.value = li.dataset.value;
        this._hideNewResults();
      });
    });
  }

  _hideNewResults() {
    if (this.hasNewResultsTarget) {
      this.newResultsTarget.classList.add("hidden");
      this.newResultsTarget.innerHTML = "";
    }
  }

  confirmNew() {
    const value = this.newInputTarget.value.trim();
    const status = this.hasNewStatusTarget ? this.newStatusTarget : null;
    if (!value) {
      if (status) {
        status.textContent = "Inserisci un codice.";
        status.classList.remove("hidden");
        status.classList.add("text-red-600", "dark:text-red-400");
      }
      return;
    }
    const params = new URLSearchParams({ field: this.fieldValue, value });
    if (this.fieldValue === "fabricode" || this.fieldValue === "varcode") {
      const itemcode = this._fieldValue("itemcode");
      if (itemcode) params.set("itemcode", itemcode);
    }
    if (this.fieldValue === "varcode") {
      const fabricode = this._fieldValue("fabricode");
      if (fabricode) params.set("fabricode", fabricode);
    }
    fetch(`${this.valueInfoUrlValue}?${params.toString()}`, { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(data => {
        if (data.exists) {
          if (status) {
            status.textContent = `Già usato in ${data.count} altra/e combinazione/i.`;
            status.classList.remove("hidden");
            status.classList.add("text-amber-600", "dark:text-amber-400");
          }
          if (this.hasUseAnywayTarget) this.useAnywayTarget.classList.remove("hidden");
        } else {
          this.selectNew(value);
        }
      });
  }

  useAnyway() {
    this.selectNew(this.newInputTarget.value.trim());
  }

  selectNew(value) {
    this.inputTarget.value = value;
    this.selected = true;
    this.newFormTarget.classList.add("hidden");
    this.newFormTarget.classList.remove("flex");
    this._hideNewResults();
    this._resetNewStatus();
    this.showAllMode = false;
    this._syncShowAllBtn();
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