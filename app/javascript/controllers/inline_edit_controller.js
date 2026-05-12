import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "gencode", "row"];

  initialize() {
    this.timeouts = {};
  }

  async update(event) {
    const input = event.target;
    const row = input.closest("tr");
    const rowIndex = row.dataset.rowIndex;
    const field = input.dataset.field;
    const value = input.value;

    const key = `${rowIndex}-${field}`;
    clearTimeout(this.timeouts[key]);

    input.dataset.editing = "true";

    this.timeouts[key] = setTimeout(async () => {
      try {
        const response = await fetch("/mainware/import/update_row", {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector("[name='csrf-token']")
              .content,
          },
          body: JSON.stringify({ row_index: rowIndex, field, value }),
        });

        if (!response.ok) throw new Error("Update failed");

        const json = await response.json();

        if (["Item Code:", "Fabric code:", "var. code:"].includes(field)) {
          const gencodeEl = row.querySelector(
            "[data-inline-edit-target='gencode']",
          );
          if (gencodeEl) gencodeEl.textContent = json.gencode;
        }

        input.dataset.editing = "saved";
        setTimeout(() => {
          delete input.dataset.editing;
        }, 1000);
      } catch (error) {
        input.dataset.editing = "error";
        setTimeout(() => {
          delete input.dataset.editing;
          input.value = input.defaultValue;
        }, 1500);
      }
    }, 300);
  }

  deleteRow(event) {
    const row = event.currentTarget.closest("tr");
    if (!confirm("Eliminare questa riga?")) return;

    const rowIndex = row.dataset.rowIndex;

    fetch(`/mainware/import/delete_row?row_index=${rowIndex}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        Accept: "text/vnd.turbo-stream.html",
      },
    }).then(async (response) => {
      const html = await response.text();
      Turbo.renderStreamMessage(html);

      const countEl = document.getElementById("import-count");
      if (countEl) {
        const current = parseInt(countEl.textContent);
        countEl.textContent = current - 1;
      }
    });
  }
}
