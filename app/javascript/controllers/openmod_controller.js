import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="openmod"
export default class extends Controller {
  toggle(e) {
    e.preventDefault();
    const src = e.target
    e.target.classList.toggle('out')
    const panel = document.getElementById(e.target.dataset.target)
    panel.classList.toggle('hidden')
  }
}
