import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "rowTemplate", "totalDebit", "totalCredit", "difference", "balanceBadge", "accountName", "accountCode"]
  static values = { accountsMap: Object }

  connect() {
    this.nextIndex = parseInt(this.rowsTarget.dataset.nextIndex || this.rowsTarget.children.length, 10)
    this.recalculate()
    this.refreshAllAccountNames()
    this.accountEntries = Object.entries(this.accountsMapValue || {})
    this.sortedEntries = this.accountEntries.slice().sort((a, b) => a[0].localeCompare(b[0], "ja", { numeric: true }))
    this.isComposing = false
    this.onCompositionStart = () => {
      this.isComposing = true
    }
    this.onCompositionEnd = (event) => {
      this.isComposing = false
      this.updateAccountName(event)
    }
    this.element.addEventListener("compositionstart", this.onCompositionStart, true)
    this.element.addEventListener("compositionend", this.onCompositionEnd, true)
  }

  disconnect() {
    this.element.removeEventListener("compositionstart", this.onCompositionStart, true)
    this.element.removeEventListener("compositionend", this.onCompositionEnd, true)
  }

  addRow() {
    const html = this.rowTemplateTarget.innerHTML.replace(/__INDEX__/g, this.nextIndex)
    this.nextIndex += 1
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.recalculate()
    const lastRow = this.rowsTarget.lastElementChild
    lastRow?.querySelector("input")?.focus()
  }

  removeRow(event) {
    const row = event.target.closest("[data-voucher-form-target='row']")
    if (!row) return

    if (this.rowsTarget.children.length <= 1) {
      row.querySelectorAll("input").forEach((input) => (input.value = ""))
    } else {
      row.remove()
    }
    this.recalculate()
  }

  recalculate() {
    let debit = 0
    let credit = 0

    this.rowsTarget.querySelectorAll('input[name$="[debit_amount]"]').forEach((input) => {
      debit += this.valueToNumber(input.value)
    })

    this.rowsTarget.querySelectorAll('input[name$="[credit_amount]"]').forEach((input) => {
      credit += this.valueToNumber(input.value)
    })

    const difference = debit - credit

    this.totalDebitTarget.textContent = this.formatAmount(debit)
    this.totalCreditTarget.textContent = this.formatAmount(credit)
    this.differenceTarget.textContent = this.formatAmount(difference)
    this.updateBadge(difference)
  }

  updateAccountName(event) {
    if (this.isComposing && event?.type !== "compositionend") return
    if (event?.isComposing) return

    const input = event.target
    const row = input.closest("[data-voucher-form-target='row']")
    if (!row) return
    const span = row.querySelector("[data-voucher-form-target='accountName']")
    if (!span) return
    const name = this.lookupAccountName(input.value)
    span.textContent = name || ""
    this.suggest(event)
  }

  refreshAllAccountNames() {
    this.accountCodeTargets.forEach((input) => {
      const row = input.closest("[data-voucher-form-target='row']")
      const span = row?.querySelector("[data-voucher-form-target='accountName']")
      if (!span) return
      span.textContent = this.lookupAccountName(input.value) || ""
    })
  }

  lookupAccountName(code) {
    if (!code) return null
    const map = this.accountsMapValue || {}
    return map[code] || null
  }

  updateBadge(difference) {
    const balanced = Math.abs(difference) < 0.005
    const ok = this.balanceBadgeTarget.dataset.badgeOkText || "バランスOK"
    const warn = this.balanceBadgeTarget.dataset.badgeWarnText || "調整してください"
    this.balanceBadgeTarget.textContent = balanced ? ok : warn
    this.balanceBadgeTarget.classList.toggle("badge--ok", balanced)
    this.balanceBadgeTarget.classList.toggle("badge--warn", !balanced)
  }

  valueToNumber(value) {
    const number = parseFloat(value)
    return Number.isFinite(number) ? number : 0
  }

  formatAmount(value) {
    return value.toLocaleString("ja-JP", { minimumFractionDigits: 0, maximumFractionDigits: 0 })
  }

  suggest(event) {
    if (this.isComposing && event?.type !== "compositionend") return
    if (event?.isComposing) return

    const input = event?.target
    if (!input) return
    const listId = input.getAttribute("list")
    if (!listId) return
    const datalist = document.getElementById(listId)
    if (!datalist) return

    if (!this.accountEntries || this.accountEntries.length === 0) {
      return
    }

    const raw = input.value.trim()
    const keyword = this.normalizeDigits(raw)
    const lower = raw.toLowerCase()
    let matches = this.sortedEntries || this.accountEntries || []

    if (keyword) {
      const numericMatches = matches.filter(([code]) => code.startsWith(keyword))
      matches = numericMatches.length > 0
        ? numericMatches
        : matches.filter(([, name]) => String(name).toLowerCase().includes(lower))
    }

    const limited = matches.slice(0, 10)
    datalist.innerHTML = limited
      .map(([code, name]) => `<option value="${this.escapeHtml(code)}">${this.escapeHtml(code)} ${this.escapeHtml(name)}</option>`)
      .join("")

    this.refreshList(input, listId)
  }

  escapeHtml(value) {
    return String(value).replace(/[&<>\"]/g, (char) => {
      switch (char) {
        case "&":
          return "&amp;"
        case "<":
          return "&lt;"
        case ">":
          return "&gt;"
        case "\"":
          return "&quot;"
        default:
          return char
      }
    })
  }

  normalizeDigits(value) {
    return value.replace(/[０-９]/g, (char) => String.fromCharCode(char.charCodeAt(0) - 0xFEE0))
  }

  refreshList(input, listId) {
    input.setAttribute("list", "")
    input.setAttribute("list", listId)
  }
}
