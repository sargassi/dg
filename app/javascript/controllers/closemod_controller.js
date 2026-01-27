import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="closemod"
export default class extends Controller {
  close(e) {
    e.preventDefault();
    const frame = document.getElementById(e.target.parentNode.dataset.targ);
    console.log(frame)
    frame.src = '';
  }
}
