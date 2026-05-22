import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "counter"]
  static values = { index: Number, length: Number }

  connect() {
    this.show(this.indexValue)
  }

  next() {
    this.show((this.indexValue + 1) % this.lengthValue)
  }

  prev() {
    this.show((this.indexValue - 1 + this.lengthValue) % this.lengthValue)
  }

  show(index) {
    this.indexValue = index
    this.slideTargets.forEach((el, i) => {
      el.classList.toggle("hidden", i !== index)
    })
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${index + 1} / ${this.lengthValue}`
    }
  }
}
