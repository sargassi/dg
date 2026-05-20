import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "spinner"]

  show() {
    this.formTarget.classList.add("hidden")
    this.spinnerTarget.classList.remove("hidden")
    this.spinnerTarget.classList.add("flex")
  }
}
