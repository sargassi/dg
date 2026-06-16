import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  selectDay(event) {
    const cell = event.currentTarget
    const day = cell.dataset.date

    document.querySelectorAll("[data-date]").forEach(c =>
      c.classList.remove("ring-2", "ring-blue-400", "ring-inset")
    )
    cell.classList.add("ring-2", "ring-blue-400", "ring-inset")

    if (day) {
      Turbo.visit(`/directory/events?start_date=${day}&selected_date=${day}`, { frame: "calendar" })
    }
  }

  closeModal(event) {
    if (event.target === event.currentTarget) {
      Turbo.visit(`/directory/events${window.location.search}`, { frame: "_top" })
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}