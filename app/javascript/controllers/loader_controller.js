import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "spinner", "overlay"]

  show() {
    if (this.hasFormTarget) {
      this.formTarget.classList.add("hidden")
    }
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
      this.overlayTarget.classList.add("flex")
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
      this.spinnerTarget.classList.add("flex")
    }
  }
}
