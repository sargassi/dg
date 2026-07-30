import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "label", "percent", "counter", "spinner", "done", "error", "errorMessage"]
  static values = { url: String, summary: String }

  connect() {
    this.emptyChecks = 0
    this.poll()
  }

  poll() {
    fetch(this.urlValue)
      .then(r => r.json())
      .then(data => {
        if (data.error) {
          this.showError(data.error)
          return
        }

        if (data.total === 0) {
          this.emptyChecks += 1
          if (this.emptyChecks > 15) {
            this.showError("L'importazione sembra bloccata. Verifica nella pagina di riepilogo o nello storico importazioni.")
            return
          }
          setTimeout(() => this.poll(), 2000)
          return
        }

        this.emptyChecks = 0
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
      .catch(() => {
        setTimeout(() => this.poll(), 5000)
      })
  }

  showError(message) {
    this.spinnerTarget.classList.add("hidden")
    this.doneTarget.classList.add("hidden")
    this.errorTarget.classList.remove("hidden")
    this.errorMessageTarget.textContent = message
    this.labelTarget.textContent = "Errore"
  }
}
