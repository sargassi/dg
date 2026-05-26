import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["rows", "template", "row"];

  add() {
    const content = this.templateTarget.innerHTML.replace(/__NEW__/g, new Date().getTime());
    this.rowsTarget.insertAdjacentHTML("beforeend", content);
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-nested-form-target='row']");
    const destroyInput = row.querySelector("input[name*='_destroy']");
    if (destroyInput) {
      destroyInput.value = "1";
      row.hidden = true;
    } else {
      row.remove();
    }
  }
}