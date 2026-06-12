import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "rowTemplate"]

  addRow() {
    const index = Number(this.rowsTarget.dataset.nextIndex)
    const html = this.rowTemplateTarget.innerHTML.replaceAll("__INDEX__", index)
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.rowsTarget.dataset.nextIndex = index + 1
  }

  removeRow(event) {
    event.currentTarget.closest("[data-invoice-form-target='row']").remove()
  }
}
