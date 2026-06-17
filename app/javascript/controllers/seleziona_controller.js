import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "basket", "basketCount", "basketItems", "form", "hiddenInputs"]

  connect() {
    this.selected = []
  }

  toggleItem(event) {
    const cb = event.currentTarget
    const row = cb.closest("tr")
    const item = {
      id: cb.dataset.id,
      gencode: cb.dataset.gencode,
      collectionId: cb.dataset.collectionId,
      collection: cb.dataset.collection,
      itemcode: cb.dataset.itemcode,
      qty: 1
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

  updateQty(event) {
    const id = event.currentTarget.dataset.id
    const item = this.selected.find(s => s.id === id)
    if (item) {
      item.qty = parseInt(event.currentTarget.value) || 1
    }
    this.renderHiddenInputs()
  }

  renderBasket() {
    if (this.selected.length === 0) {
      this.basketTarget.classList.add("hidden")
      return
    }

    this.basketTarget.classList.remove("hidden")
    this.basketCountTarget.textContent = `${this.selected.length} articoli selezionati`

    this.basketItemsTarget.innerHTML = this.selected.map(item => `
      <div class="flex items-center gap-2 py-1.5 border-b border-slate-100 last:border-0">
        <div class="flex-1 min-w-0">
          <div class="text-xs font-mono text-blue-600 font-semibold truncate">${this.escape(item.gencode)}</div>
          <div class="text-[10px] text-slate-400 truncate">${this.escape(item.collection || '')}</div>
        </div>
        <input type="number" value="${item.qty}" min="1"
               data-id="${item.id}"
               data-action="change->seleziona#updateQty"
               class="w-14 text-xs border border-slate-300 outline-none px-1 py-0.5 text-center rounded-sm">
        <button type="button"
                data-action="click->seleziona#removeItem"
                data-id="${item.id}"
                class="text-slate-400 hover:text-red-500 transition flex-shrink-0">
          <span class="material-symbols-outlined text-sm">close</span>
        </button>
      </div>
    `).join("")

    this.renderHiddenInputs()
  }

  renderHiddenInputs() {
    this.hiddenInputsTarget.innerHTML = this.selected.map(item => `
      <input type="hidden" name="selected[][item_id]" value="${item.id}">
      <input type="hidden" name="selected[][gencode]" value="${item.gencode}">
      <input type="hidden" name="selected[][collection_id]" value="${item.collectionId}">
      <input type="hidden" name="selected[][qty]" value="${item.qty}">
    `).join("")
  }

  syncFrame() {
    this.selected.forEach(item => {
      const cb = this.checkboxTargets.find(c => c.dataset.id === item.id)
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
