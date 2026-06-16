import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "label", "percent", "counter", "spinner", "done"]
  static values = { url: String, summary: String }

  connect() {
    this.poll()
  }

  poll() {
    fetch(this.urlValue)
      .then(r => r.json())
      .then(data => {
        if (data.total === 0) return

        const pct = Math.round((data.done / data.total) * 100)
        this.barTarget.style.width = `${pct}%`
        this.percentTarget.textContent = `${pct}%`
        this.counterTarget.textContent = `${data.done} / ${data.total}`

        if (data.complete) {
          this.spinnerTarget.classList.add("hidden")
          this.doneTarget.classList.remove("hidden")
          this.labelTarget.textContent = "Completato!"
        } else {
          setTimeout(() => this.poll(), 2000)
        }
      })
      .catch(() => setTimeout(() => this.poll(), 5000))
  }
}