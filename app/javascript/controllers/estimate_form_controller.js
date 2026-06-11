import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "row", "rowTemplate", "destroyFlag"]

  addRow() {
    const index = Number(this.rowsTarget.dataset.nextIndex)
    const html = this.rowTemplateTarget.innerHTML.replaceAll("__INDEX__", index)
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.rowsTarget.dataset.nextIndex = index + 1
  }

  removeRow(event) {
    const row = event.currentTarget.closest("[data-estimate-form-target='row']")
    const destroyFlag = row.querySelector("[data-estimate-form-target='destroyFlag']")

    if (destroyFlag && row.querySelector("input[name*='[id]']")) {
      destroyFlag.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }
}
