import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "row", "count", "form"];
  static values = { debounce: { type: Number, default: 150 } };

  initialize() {
    this.timeout = null;
  }

  onFrameLoad() {
    this.highlight();
    this.updateCount();
  }

  updateCount() {
    if (!this.hasCountTarget) return;
    const hidden = this.element.querySelector("[data-filtered-count]");
    if (hidden) this.countTarget.textContent = hidden.textContent;
  }

  highlight() {
    this.element.querySelectorAll("mark.search-highlight").forEach((m) => {
      m.replaceWith(m.textContent);
    });

    const query = this.inputTarget?.value?.trim();
    if (!query) return;

    const re = new RegExp(`(${this._escapeRegExp(query)})`, "gi");

    this.element.querySelectorAll("td").forEach((td) => {
      if (td.closest("[data-search-filter-target]")) return;
      if (td.querySelector("svg")) return;
      this._highlightTextNode(td, re);
    });
  }

  _highlightTextNode(el, re) {
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null, false);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach((node) => {
      if (!node.parentNode) return;
      const match = node.textContent.match(re);
      if (!match) return;
      const frag = document.createDocumentFragment();
      let lastIdx = 0;
      node.textContent.replace(re, (matched, _, idx) => {
        frag.appendChild(document.createTextNode(node.textContent.slice(lastIdx, idx)));
        const mark = document.createElement("mark");
        mark.className = "search-highlight bg-yellow-200 rounded px-0.5";
        mark.textContent = matched;
        frag.appendChild(mark);
        lastIdx = idx + matched.length;
      });
      frag.appendChild(document.createTextNode(node.textContent.slice(lastIdx)));
      node.parentNode.replaceChild(frag, node);
    });
  }

  _escapeRegExp(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  filter(event) {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      if (this.hasFormTarget) {
        this.formTarget.requestSubmit();
      } else if (this.hasRowTarget) {
        const query = event.target.value.toLowerCase().trim();
        const visible = this.rowTargets.filter((row) => {
          const text = row.textContent.toLowerCase();
          row.hidden = query.length > 0 && !text.includes(query);
          return !row.hidden;
        });
        if (this.hasCountTarget) {
          this.countTarget.textContent = visible.length;
        }
      }
    }, this.debounceValue);
  }
}
