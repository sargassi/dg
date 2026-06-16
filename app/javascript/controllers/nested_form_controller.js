import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["rows", "template", "row"];

  connect() {
    if (this.rowsTarget.children.length === 0) {
      this.add();
    }
  }

  add() {
    const content = this.templateTarget.innerHTML.replace(/__NEW__/g, new Date().getTime());
    this.rowsTarget.insertAdjacentHTML("beforeend", content);
    const row = this.rowsTarget.lastElementChild;
    this._applyDefaults(row);
    this._watchRow(row);
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

  _applyDefaults(row) {
    const defaultsEl = this.element.closest("[data-controller='defaults']") || document.querySelector("[data-controller='defaults']");
    if (!defaultsEl) return;
    const whSel = defaultsEl.querySelector("[data-defaults-target='warehouse']");
    const locSel = defaultsEl.querySelector("[data-defaults-target='location']");
    const whVal = whSel?.value;
    const locVal = locSel?.value;
    const whTxt = whVal && whSel.selectedOptions[0] ? whSel.selectedOptions[0].text : "";
    const locTxt = locVal && locSel.selectedOptions[0] ? locSel.selectedOptions[0].text : "";

    const whHidden = row.querySelector("input[type='hidden'][name*='warehouse_id']");
    const locHidden = row.querySelector("input[type='hidden'][name*='location_id']");
    const whSpan = row.querySelector(".wh-display");
    const locSpan = row.querySelector(".loc-display");
    if (whHidden) whHidden.value = whVal || "";
    if (locHidden) locHidden.value = locVal || "";
    if (whSpan) whSpan.textContent = whTxt ? `Mag: ${whTxt}` : "—";
    if (locSpan) locSpan.textContent = locTxt ? `Ubi: ${locTxt}` : "—";
  }

  _watchRow(row) {
    const codeInput = row.querySelector("input[type='text']");
    const whHidden = row.querySelector("input[type='hidden'][name*='warehouse_id']");

    const check = () => {
      const codeDone = codeInput && codeInput.value.trim().length > 0;
      const whDone = whHidden && whHidden.value.trim().length > 0;
      if (codeDone && whDone) {
        const nextRow = row.nextElementSibling;
        if (!nextRow || nextRow.hidden) {
          this.add();
        }
      }
    };

    if (codeInput) {
      codeInput.addEventListener("input", check);
      codeInput.addEventListener("blur", check);
    }
    if (whHidden) {
      const observer = new MutationObserver(check);
      observer.observe(whHidden, { attributes: true, attributeFilter: ["value"] });
    }
  }
}
