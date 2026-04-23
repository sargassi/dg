import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="setpdfilter"
export default class extends Controller {
  set(e) {
    //const pdf = document.getElementById("pdfet");
    const form = e.target.parentNode;
    //pdf.dataset.group = e.target.value;
    //pdf.href = document.location.pathname + "?group=" + pdf.dataset.group;
    form.submit();
  }
}
