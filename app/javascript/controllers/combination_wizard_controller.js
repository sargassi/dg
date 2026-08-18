import { Controller } from "@hotwired/stimulus";

const ORDER = ["itemcode", "fabricode", "varcode"];

export default class extends Controller {
  static targets = [
    "stepper", "stepDot", "stepState", "pending",
    "codesPanel", "detailsPanel", "continueBtn",
    "step", "search", "input", "results",
    "newForm", "newInput", "newResults", "newStatus", "useAnyway",
    "selected", "selectedCode", "hidden",
    "field", "collection", "preview", "autofill"
  ];
  static values = {
    url: String,
    infoUrl: String,
    valueInfoUrl: String,
    delay: { type: Number, default: 200 }
  };

  connect() {
    this._timer = null;
    this.suggestions = null;
    this.showAllFields = {};
    this._renderSteps();
    this.fieldTargets.forEach(f => {
      f.addEventListener("change", () => this._toggleAutofill());
    });
    if (this.hasCollectionTarget) {
      this.collectionTarget.addEventListener("change", () => this._finalCheck());
    }
  }

  disconnect() {
    clearTimeout(this._timer);
  }

  // ---------- step navigation ----------

  _value(field) {
    const hidden = this.hiddenTargets.find(t => t.dataset.field === field);
    return hidden ? hidden.value.trim() : "";
  }

  _setValue(field, value) {
    const hidden = this.hiddenTargets.find(t => t.dataset.field === field);
    if (hidden) hidden.value = value;
  }

  _activeStep() {
    return ORDER.find(field => !this._value(field));
  }

  _element(targets, field) {
    return targets.find(t => t.dataset.field === field);
  }

  _renderSteps() {
    const active = this._activeStep();
    ORDER.forEach(field => {
      const step = this._element(this.stepTargets, field);
      if (!step) return;

      if (this._value(field)) {
        step.classList.remove("opacity-60", "border-dashed");
        step.classList.add("border-green-200", "dark:border-green-700");
        this._showSelected(field);
        this._setStepState(field, "done");
      } else if (field === active) {
        step.classList.remove("opacity-60", "border-dashed", "border-green-200", "dark:border-green-700");
        step.classList.add("border-accent", "dark:border-accent", "ring-1", "ring-accent/20");
        this._showSearch(field);
        this._setStepState(field, "active");
      } else {
        step.classList.add("opacity-60");
        step.classList.remove("border-accent", "dark:border-accent", "ring-1", "ring-accent/20", "border-green-200", "dark:border-green-700");
        this._showPending(field);
        this._setStepState(field, "pending");
      }
    });
    this._updateStepper(active);
    this._updateContinue();
    if (!active) this._finalCheck();
  }

  _setStepState(field, state) {
    const stateEl = this._element(this.stepStateTargets, field);
    if (!stateEl) return;
    stateEl.classList.remove("text-green-600", "dark:text-green-400", "text-accent-700", "dark:text-accent-300", "text-slate-400", "dark:text-slate-500");
    if (state === "done") {
      stateEl.textContent = "Completato";
      stateEl.classList.add("text-green-600", "dark:text-green-400");
    } else if (state === "active") {
      stateEl.textContent = "In corso";
      stateEl.classList.add("text-accent-700", "dark:text-accent-300");
    } else {
      stateEl.textContent = "In attesa";
      stateEl.classList.add("text-slate-400", "dark:text-slate-500");
    }
  }

  _showSearch(field) {
    const search = this._element(this.searchTargets, field);
    const newForm = this._element(this.newFormTargets, field);
    const selected = this._element(this.selectedTargets, field);
    const pending = this._element(this.pendingTargets, field);
    if (search) search.classList.remove("hidden");
    if (search) search.classList.add("block");
    if (newForm) newForm.classList.add("hidden");
    if (selected) selected.classList.add("hidden");
    if (pending) pending.classList.add("hidden");
  }

  _showSelected(field) {
    const search = this._element(this.searchTargets, field);
    const newForm = this._element(this.newFormTargets, field);
    const selected = this._element(this.selectedTargets, field);
    const pending = this._element(this.pendingTargets, field);
    const code = this._element(this.selectedCodeTargets, field);
    if (search) search.classList.add("hidden");
    if (newForm) newForm.classList.add("hidden");
    if (selected) selected.classList.remove("hidden");
    if (selected) selected.classList.add("flex");
    if (pending) pending.classList.add("hidden");
    if (code) code.textContent = this._value(field);
  }

  _showPending(field) {
    const search = this._element(this.searchTargets, field);
    const newForm = this._element(this.newFormTargets, field);
    const selected = this._element(this.selectedTargets, field);
    const pending = this._element(this.pendingTargets, field);
    if (search) search.classList.add("hidden");
    if (newForm) newForm.classList.add("hidden");
    if (selected) selected.classList.add("hidden");
    if (pending) pending.classList.remove("hidden");
    if (pending) pending.classList.add("flex");
  }

  _updateStepper(active) {
    this.stepDotTargets.forEach(dot => {
      const field = dot.dataset.field;
      const circle = dot.querySelector("span");
      const isDone = field === "details" ? false : this._value(field) !== "";
      const isActive = field === active;
      dot.classList.remove("text-slate-400", "dark:text-slate-500", "text-accent-700", "dark:text-accent-300", "text-green-600", "dark:text-green-400");
      circle.classList.remove("bg-accent", "border-accent", "text-white", "bg-green-600", "border-green-600", "border-slate-300", "dark:border-slate-600", "text-slate-400", "dark:text-slate-500");
      if (isDone) {
        dot.classList.add("text-green-600", "dark:text-green-400");
        circle.classList.add("bg-green-600", "border-green-600", "text-white");
      } else if (isActive) {
        dot.classList.add("text-accent-700", "dark:text-accent-300");
        circle.classList.add("bg-accent", "border-accent", "text-white");
      } else {
        dot.classList.add("text-slate-400", "dark:text-slate-500");
        circle.classList.add("border-slate-300", "dark:border-slate-600", "text-slate-400", "dark:text-slate-500");
      }
    });
  }

  _updateContinue() {
    if (!this.hasContinueBtnTarget) return;
    const allSet = ORDER.every(field => this._value(field));
    this.continueBtnTarget.classList.toggle("hidden", !allSet);
  }

  continue() {
    if (!ORDER.every(field => this._value(field))) return;
    this.codesPanelTarget.classList.add("hidden");
    this.detailsPanelTarget.classList.remove("hidden");
    this._finalCheck();
    const first = this.fieldTargets[0];
    if (first) first.focus();
  }

  back() {
    this.detailsPanelTarget.classList.add("hidden");
    this.codesPanelTarget.classList.remove("hidden");
    this._renderSteps();
  }

  editStep(event) {
    const field = event.currentTarget.dataset.field;
    ORDER.slice(ORDER.indexOf(field)).forEach(f => {
      this._setValue(f, "");
      this.showAllFields[f] = false;
    });
    this.back();
    const input = this._element(this.inputTargets, field);
    if (input) input.focus();
  }

  // ---------- autocomplete ----------

  _searchUrl(field, q) {
    const params = new URLSearchParams({ field, q });
    if (!q) params.set("limit", "200");
    if (!this.showAllFields[field]) {
      if (field === "fabricode") {
        const itemcode = this._value("itemcode");
        if (itemcode) params.set("itemcode", itemcode);
      } else if (field === "varcode") {
        const itemcode = this._value("itemcode");
        const fabricode = this._value("fabricode");
        if (itemcode) params.set("itemcode", itemcode);
        if (fabricode) params.set("fabricode", fabricode);
      }
    }
    return `${this.urlValue}?${params.toString()}`;
  }

  _allUrl(field) {
    const input = this._element(this.inputTargets, field);
    const q = input ? input.value.trim() : "";
    const params = new URLSearchParams({ field, q });
    params.set("limit", "200");
    return `${this.urlValue}?${params.toString()}`;
  }

  showAll(event) {
    const field = event.currentTarget.dataset.field;
    this.showAllFields[field] = true;
    fetch(this._allUrl(field), { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(data => this._renderResults(field, data));
  }

  preventBlur(event) {
    event.preventDefault();
  }

  search(event) {
    clearTimeout(this._timer);
    const input = event.currentTarget;
    const field = input.dataset.field;
    const q = input.value.trim();
    this._timer = setTimeout(() => {
      fetch(this._searchUrl(field, q), { headers: { Accept: "application/json" } })
        .then(r => r.json())
        .then(data => this._renderResults(field, data));
    }, this.delayValue);
  }

  _renderResults(field, data) {
    const results = this._element(this.resultsTargets, field);
    if (!results) return;
    if (data.length === 0) {
      this._hideResults(field);
      return;
    }
    results.innerHTML = data.map(value =>
      `<li role="option" data-value="${this._escape(value)}" class="px-3 py-2 text-xs cursor-pointer hover:bg-accent-50 border-b border-slate-100 last:border-0 font-mono">${this._escape(value)}</li>`
    ).join("");
    results.classList.remove("hidden");
    results.querySelectorAll("li[data-value]").forEach(li => {
      li.addEventListener("click", () => {
        this.selectValue(field, li.dataset.value);
        this._hideResults(field);
      });
    });
  }

  hideResults(event) {
    const field = event.currentTarget.dataset.field;
    setTimeout(() => this._hideResults(field), 200);
  }

  _hideResults(field) {
    const results = this._element(this.resultsTargets, field);
    if (results) {
      results.classList.add("hidden");
      results.innerHTML = "";
    }
  }

  preventEnter(event) {
    event.preventDefault();
  }

  selectValue(field, value) {
    this._setValue(field, value);
    this._resetNew(field);
    this._closeModal(field);
    this.showAllFields[field] = false;
    this._renderSteps();
    const next = ORDER[ORDER.indexOf(field) + 1];
    const input = this._element(this.inputTargets, next);
    if (input) input.focus();
  }

  // ---------- create new ----------

  toggleNew(event) {
    const field = event.currentTarget.dataset.field;
    const newForm = this._element(this.newFormTargets, field);
    const newInput = this._element(this.newInputTargets, field);
    this._resetNew(field);
    this._hideNewResults(field);
    if (newForm) {
      newForm.classList.remove("hidden");
      newForm.classList.add("flex");
    }
    if (newInput) newInput.focus();
  }

  cancelNew(event) {
    const field = event.currentTarget.dataset.field;
    this._closeModal(field);
    this._resetNew(field);
  }

  backdropClick(event) {
    if (event.target === event.currentTarget) this.cancelNew(event);
  }

  stop(event) {
    event.stopPropagation();
  }

  _closeModal(field) {
    const newForm = this._element(this.newFormTargets, field);
    if (newForm) {
      newForm.classList.add("hidden");
      newForm.classList.remove("flex");
    }
    this._hideNewResults(field);
  }

  searchNew(event) {
    clearTimeout(this._timer);
    const input = event.currentTarget;
    const field = input.dataset.field;
    const q = input.value.trim();
    if (q.length < 1) {
      this._hideNewResults(field);
      return;
    }
    this._timer = setTimeout(() => {
      const params = new URLSearchParams({ field, q });
      params.set("limit", "20");
      fetch(`${this.urlValue}?${params.toString()}`, { headers: { Accept: "application/json" } })
        .then(r => r.json())
        .then(data => this._renderNewResults(field, data));
    }, this.delayValue);
  }

  _renderNewResults(field, data) {
    const results = this._element(this.newResultsTargets, field);
    if (!results) return;
    if (!data || data.length === 0) {
      this._hideNewResults(field);
      return;
    }
    results.innerHTML = data.map(value =>
      `<li role="option" data-value="${this._escape(value)}" class="px-3 py-2 text-xs cursor-pointer hover:bg-accent-50 border-b border-slate-100 last:border-0 font-mono">${this._escape(value)}</li>`
    ).join("");
    results.classList.remove("hidden");
    results.querySelectorAll("li[data-value]").forEach(li => {
      li.addEventListener("click", () => {
        const input = this._element(this.newInputTargets, field);
        if (input) input.value = li.dataset.value;
        this._hideNewResults(field);
      });
    });
  }

  _hideNewResults(field) {
    const results = this._element(this.newResultsTargets, field);
    if (results) {
      results.classList.add("hidden");
      results.innerHTML = "";
    }
  }

  _resetNew(field) {
    const newInput = this._element(this.newInputTargets, field);
    const status = this._element(this.newStatusTargets, field);
    const useAnyway = this._element(this.useAnywayTargets, field);
    if (newInput) newInput.value = "";
    if (status) {
      status.textContent = "";
      status.classList.add("hidden");
    }
    if (useAnyway) useAnyway.classList.add("hidden");
  }

  confirmNew(event) {
    const field = event.currentTarget.dataset.field;
    const input = this._element(this.newInputTargets, field);
    const status = this._element(this.newStatusTargets, field);
    const value = input.value.trim();
    if (!value) {
      status.textContent = "Inserisci un codice.";
      status.classList.remove("hidden");
      status.classList.add("text-red-600", "dark:text-red-400");
      return;
    }
    const params = new URLSearchParams({ field, value });
    if (field === "fabricode") {
      const itemcode = this._value("itemcode");
      if (itemcode) params.set("itemcode", itemcode);
    } else if (field === "varcode") {
      const itemcode = this._value("itemcode");
      const fabricode = this._value("fabricode");
      if (itemcode) params.set("itemcode", itemcode);
      if (fabricode) params.set("fabricode", fabricode);
    }
    fetch(`${this.valueInfoUrlValue}?${params.toString()}`, { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(data => {
        if (data.exists) {
          status.textContent = `Già usato in ${data.count} altra/e combinazione/i.`;
          status.classList.remove("hidden");
          status.classList.add("text-amber-600", "dark:text-amber-400");
          const useAnyway = this._element(this.useAnywayTargets, field);
          if (useAnyway) useAnyway.classList.remove("hidden");
        } else {
          this.selectValue(field, value);
        }
      });
  }

  useAnyway(event) {
    const field = event.currentTarget.dataset.field;
    const input = this._element(this.newInputTargets, field);
    this.selectValue(field, input.value.trim());
  }

  // ---------- preview / autofill ----------

  _finalCheck() {
    if (!ORDER.every(field => this._value(field))) {
      this._renderPreview(null);
      return;
    }
    const params = new URLSearchParams({
      itemcode: this._value("itemcode"),
      fabricode: this._value("fabricode"),
      varcode: this._value("varcode")
    });
    if (this.hasCollectionTarget && this.collectionTarget.value) {
      params.set("collection_id", this.collectionTarget.value);
    }
    fetch(`${this.infoUrlValue}?${params.toString()}`, { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(data => this._renderPreview(data));
  }

  _renderPreview(data) {
    this.suggestions = data && data.suggestions ? data.suggestions : null;

    if (!data || !data.composed) {
      this.previewTarget.classList.add("hidden");
      this._toggleAutofill();
      return;
    }

    const codes = [`<span class="font-mono">${this._escape(data.composed)}</span>`];
    if (data.gencode) {
      codes.push(`<span class="text-slate-500 dark:text-slate-400">→</span> <span class="font-mono">${this._escape(data.gencode)}</span>`);
    }

    let status;
    if (data.exact_exists) {
      status = `<span class="text-red-600 dark:text-red-400 font-semibold">Già presente in questa collezione</span>`;
    } else if (data.siblings && data.siblings.length > 0) {
      const cols = data.siblings
        .map(s => `<strong>${this._escape(s.collection || "-")}</strong>`)
        .join(", ");
      status = `<span class="text-amber-700 dark:text-amber-400 font-semibold">Combinazione già presente in: ${cols}</span>`;
    } else {
      status = `<span class="text-emerald-700 dark:text-emerald-400 font-semibold">Nuova combinazione</span>`;
    }

    this.previewTarget.innerHTML = `${codes.join(" ")} — ${status}`;
    this.previewTarget.classList.remove("hidden");
    this._applySuggestions(false);
  }

  autofill() {
    this._applySuggestions(true);
  }

  _applySuggestions(force) {
    if (!this.suggestions) return;
    Object.entries(this.suggestions).forEach(([name, value]) => {
      const field = this.fieldTargets.find(t => t.dataset.fieldName === name);
      if (field && (force || !field.value)) {
        field.value = value || "";
      }
    });
    this._toggleAutofill();
  }

  _toggleAutofill() {
    if (!this.suggestions) {
      this.autofillTarget.classList.add("hidden");
      return;
    }
    const anyEmpty = this.fieldTargets.some(t => !t.value);
    this.autofillTarget.classList.toggle("hidden", !anyEmpty);
  }

  _escape(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}