import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="closemod"
export default class extends Controller {
  close(e) {
    e.preventDefault();
    const frame = document.getElementById(this.data.get('target'));
    frame.innerHTML = '';
  }
}
