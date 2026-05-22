import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "hidden"]
  static values = { max: { type: Number, default: 10 } }

  connect() {
    this._files = []
  }

  preview() {
    const incoming = Array.from(this.inputTarget.files).slice(0, this.maxValue)
    this._files = incoming.filter(f => f.type.startsWith("image/"))
    this.render()
  }

  remove(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this._files.splice(index, 1)
    this.syncInput()
    this.render()
  }

  render() {
    this.previewTarget.innerHTML = ""
    this._files.forEach((file, i) => {
      const url = URL.createObjectURL(file)
      const wrapper = document.createElement("div")
      wrapper.className = "relative group shrink-0 cursor-pointer"
      wrapper.dataset.index = i
      wrapper.dataset.action = "click->image-preview#remove"
      wrapper.innerHTML = `
        <img src="${url}" class="w-16 h-16 object-cover rounded-sm border border-slate-200">
        <div class="absolute -top-1.5 -right-1.5 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition text-xs leading-none">✕</div>
      `
      this.previewTarget.appendChild(wrapper)
    })
  }

  removeExisting(event) {
    const wrapper = event.currentTarget.closest("[data-signed-id]")
    if (wrapper) {
      const hidden = wrapper.querySelector("[data-image-preview-target='hidden']")
      if (hidden) hidden.remove()
      wrapper.remove()
    }
  }

  syncInput() {
    const dt = new DataTransfer()
    this._files.forEach(f => dt.items.add(f))
    this.inputTarget.files = dt.files
  }
}
