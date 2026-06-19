import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "row", "form", "count", "select"];
  static values = { debounce: { type: Number, default: 150 } };

  initialize() {
    this.timeout = null;
    this.originalTexts = new Map();
  }

  connect() {
    this._highlightSelects();
    if (!this.hasFormTarget) {
      this.rowTargets.forEach((row) => {
        row.querySelectorAll("td").forEach((cell, idx) => {
          const key = `${row.rowIndex}-${idx}`;
          this.originalTexts.set(key, cell.textContent);
          cell.dataset.cellKey = key;
        });
      });
    }
  }

  onFrameLoad() {
    this._highlightSelects();
    const hiddenCount = this.element.querySelector("[data-filtered-count]");
    if (hiddenCount && this.hasCountTarget) {
      this.countTarget.textContent = `${hiddenCount.textContent} articoli`;
    }
    if (!this.hasInputTarget) return;
    this.inputTarget.focus();
    const query = this.inputTarget.value.trim();
    if (query.length > 0) this._highlightFrame(query);
  }

  _highlightSelects() {
    this.selectTargets.forEach((el) => {
      const hasValue = el.value !== '' && el.value !== null;
      const active = (el.dataset.searchFilterActiveClass || '').split(' ').filter(Boolean);
      const inactive = (el.dataset.searchFilterInactiveClass || '').split(' ').filter(Boolean);
      active.forEach((c) => el.classList.toggle(c, hasValue));
      inactive.forEach((c) => el.classList.toggle(c, !hasValue));
    });
  }

  _highlightFrame(query) {
    const frame = this.element.querySelector("turbo-frame");
    if (!frame) return;
    const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const regex = new RegExp(`(${escaped})`, "gi");
    const walker = document.createTreeWalker(frame, NodeFilter.SHOW_TEXT, null, false);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach((node) => {
      const text = node.textContent;
      if (!text || !regex.test(text)) return;
      const frag = document.createDocumentFragment();
      let lastIdx = 0;
      regex.lastIndex = 0;
      text.replace(regex, (match, _, offset) => {
        if (offset > lastIdx) frag.append(text.slice(lastIdx, offset));
        const mark = document.createElement("mark");
        mark.className = "bg-yellow-200 text-slate-800 rounded px-0.5";
        mark.textContent = match;
        frag.append(mark);
        lastIdx = offset + match.length;
      });
      if (lastIdx < text.length) frag.append(text.slice(lastIdx));
      node.replaceWith(frag);
    });
  }

  filter(event) {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      if (this.hasFormTarget) {
        this.formTarget.requestSubmit();
      } else {
        this._filterRows(event.target.value);
      }
    }, this.debounceValue);
  }

  _filterRows(rawQuery) {
    const query = rawQuery.toLowerCase().trim();

    this.rowTargets.forEach((row) => {
      const text = row.textContent.toLowerCase();
      const isMatch = query.length === 0 || text.includes(query);
      row.hidden = !isMatch;

      if (isMatch && query.length > 0) {
        this.highlightCells(row, query);
      } else {
        this.resetCells(row);
      }
    });

    if (this.hasCountTarget) {
      const visible = this.rowTargets.filter((r) => !r.hidden).length;
      const total = this.rowTargets.length;
      this.countTarget.textContent = `${visible} / ${total}`;
    }
  }

  highlightCells(row, query) {
    row.querySelectorAll("td").forEach((cell) => {
      const key = cell.dataset.cellKey;
      const original = this.originalTexts.get(key) || "";
      const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const regex = new RegExp(`(${escaped})`, "gi");
      cell.innerHTML = original.replace(
        regex,
        '<mark class="bg-yellow-200 text-slate-800 rounded px-0.5">$1</mark>',
      );
    });
  }

  resetCells(row) {
    row.querySelectorAll("td").forEach((cell) => {
      const key = cell.dataset.cellKey;
      cell.textContent = this.originalTexts.get(key) || "";
    });
  }
}
