import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static values = { storageKey: String }

  connect() {
    this.hiddenColumns = this.loadHiddenColumns()
    this.render()
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    window.addEventListener("click", this.closeOnClickOutside)
  }

  disconnect() {
    window.removeEventListener("click", this.closeOnClickOutside)
  }

  toggleMenu(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  hideMenu() {
    this.menuTarget.classList.add("hidden")
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideMenu()
    }
  }

  toggle(event) {
    const index = parseInt(event.target.dataset.index, 10)
    if (event.target.checked) {
      this.hiddenColumns.delete(index)
    } else {
      this.hiddenColumns.add(index)
    }
    this.saveHiddenColumns()
    this.render()
  }

  render() {
    const checkboxes = this.element.querySelectorAll("[data-column-toggle-checkbox]")
    checkboxes.forEach(box => {
      const index = parseInt(box.dataset.index, 10)
      box.checked = !this.hiddenColumns.has(index)
    })

    this.hiddenColumns.forEach(index => {
      const selector = `table tr > *:nth-child(${index + 1})`
      this.element.querySelectorAll(selector).forEach(el => el.classList.add("hidden"))
    })
  }

  loadHiddenColumns() {
    try {
      const raw = localStorage.getItem(this.storageKeyValue)
      return new Set(raw ? JSON.parse(raw) : [])
    } catch {
      return new Set()
    }
  }

  saveHiddenColumns() {
    localStorage.setItem(this.storageKeyValue, JSON.stringify(Array.from(this.hiddenColumns)))
  }
}
