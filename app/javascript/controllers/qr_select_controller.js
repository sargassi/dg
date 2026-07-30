import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "basket", "basketCount", "basketItems", "form", "hiddenInputs"]

  connect() {
    this.selected = []
  }

  toggleItem(event) {
    const cb = event.currentTarget
    const row = cb.closest("tr")
    const qrEl = row?.querySelector(".qr-code-hidden")
    const item = {
      id: cb.dataset.id,
      gencode: cb.dataset.gencode,
      collectionId: cb.dataset.collectionId,
      collection: cb.dataset.collection,
      itemcode: cb.dataset.itemcode,
      qrSvg: qrEl ? qrEl.innerHTML : "",
    }

    if (cb.checked) {
      this.selected.push(item)
      if (row) row.classList.add("bg-green-200")
    } else {
      this.selected = this.selected.filter(s => s.id !== item.id)
      if (row) row.classList.remove("bg-green-200")
    }

    this.renderBasket()
  }

  removeItem(event) {
    const id = event.currentTarget.dataset.id
    this.selected = this.selected.filter(s => s.id !== id)
    const cb = this.checkboxTargets.find(c => c.dataset.id === id)
    if (cb) {
      cb.checked = false
      const row = cb.closest("tr")
      if (row) row.classList.remove("bg-green-200")
    }
    this.renderBasket()
  }

  renderBasket() {
    if (this.selected.length === 0) {
      this.basketTarget.classList.add("hidden")
      return
    }

    this.basketTarget.classList.remove("hidden")
    this.basketCountTarget.textContent = `${this.selected.length} articoli selezionati`

    this.basketItemsTarget.innerHTML = this.selected.map(item => `
      <div class="flex gap-2 py-2 border-b border-slate-100 last:border-0 items-start">
        <div class="w-16 h-16 flex-shrink-0 flex items-center justify-center bg-white border border-slate-100 rounded">
          ${item.qrSvg || '<span class="text-[8px] text-slate-300">N/A</span>'}
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-xs font-mono text-blue-600 font-semibold truncate">${this.escape(item.gencode)}</div>
          <div class="text-[10px] text-slate-500 truncate">${this.escape(item.collection || '')}</div>
          <div class="text-[10px] text-slate-400 truncate">${this.escape(item.itemcode || '')}</div>
        </div>
        <button type="button"
                data-action="click->qr-select#removeItem"
                data-id="${item.id}"
                class="text-slate-400 hover:text-red-500 transition flex-shrink-0 mt-1">
          <span class="material-symbols-outlined text-sm">close</span>
        </button>
      </div>
    `).join("")

    this.renderHiddenInputs()
  }

  renderHiddenInputs() {
    this.hiddenInputsTarget.innerHTML = this.selected.map(item => `
      <input type="hidden" name="selected[][item_id]" value="${item.id}">
    `).join("")
  }

  syncFrame() {
    this.selected.forEach(item => {
      const cb = this.element.querySelector(`[data-qr-select-target="checkbox"][data-id="${item.id}"]`)
      if (cb) {
        cb.checked = true
        const row = cb.closest("tr")
        if (row) row.classList.add("bg-green-200")
      }
    })
    this.renderBasket()
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
