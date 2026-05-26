import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "row", "count", "form", "select"];
  static values = { debounce: { type: Number, default: 150 } };

  initialize() {
    this.timeout = null;
  }

  connect() {
    this.selectTargets.forEach(el => this.highlightSelect(el));
  }

  onFrameLoad() {
    this.highlight();
    this.updateCount();
    this.selectTargets.forEach(el => this.highlightSelect(el));
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

    this.element.querySelectorAll("td, [data-highlightable]").forEach((el) => {
      if (el.closest("[data-search-filter-target]")) return;
      if (el.querySelector("svg, img")) return;
      this._highlightTextNode(el, re);
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

  highlightSelect(select) {
    if (select.value) {
      select.classList.add("bg-blue-400", "text-white");
      select.classList.remove("bg-white");
    } else {
      select.classList.remove("bg-blue-400", "text-white");
      select.classList.add("bg-white");
    }
  }

  filter(event) {
    if (event.target.matches("select")) this.highlightSelect(event.target);
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
