import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="formsubmit"
export default class extends Controller {
  go(e) {
    e.preventDefault();
    let go = e.target.parentNode
    go.submit();
  }
}
