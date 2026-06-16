import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const group = event.currentTarget.dataset.group
    this.element.querySelectorAll(`[data-spostamenti-group="${group}"]`).forEach(el => {
      el.classList.toggle("hidden")
    })
  }

  toggleWh(event) {
    const wh = event.currentTarget.dataset.whGroup
    this.element.querySelectorAll(`[data-spostamenti-wh-group="${wh}"]`).forEach(el => {
      el.classList.toggle("hidden")
    })
  }
}
