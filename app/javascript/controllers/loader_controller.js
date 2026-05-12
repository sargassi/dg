import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "spinner"]

  show() {
    this.formTarget.hidden = true
    this.spinnerTarget.hidden = false
  }
}
