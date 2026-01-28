import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="autosub"
export default class extends Controller {
  connect() {}

  go(e) {
    const ff = e.target.parentNode;
    ff.submit();
  }
}
