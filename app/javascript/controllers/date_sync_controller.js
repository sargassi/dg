import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["start", "end"]

  syncEnd() {
    const start = this.startTarget.value
    const end = this.endTarget.value

    if (start && (!end || end < start)) {
      this.endTarget.value = start
    }
  }
}
