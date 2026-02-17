import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "nextBalance", "counterpart", "description", "recordedOn"]
  static values = { currentBalance: Number, focusOnLoad: String }

  connect() {
    this.recalculate()
    this.focusForContinuousEntry()
  }

  recalculate() {
    if (!this.hasNextBalanceTarget) return

    const currentBalance = Number(this.currentBalanceValue || 0)
    const amount = this.parseNumber(this.hasAmountTarget ? this.amountTarget.value : "")
    const nextBalance = currentBalance + amount
    this.nextBalanceTarget.value = this.formatNumber(nextBalance)
  }

  parseNumber(value) {
    const normalized = String(value || "").replace(/,/g, "").trim()
    if (normalized === "") return 0
    const parsed = Number(normalized)
    return Number.isFinite(parsed) ? parsed : 0
  }

  formatNumber(value) {
    return Number(value || 0).toLocaleString("ja-JP", { maximumFractionDigits: 0 })
  }

  focusForContinuousEntry() {
    const focusField = this.focusOnLoadValue
    if (!focusField) return

    const target = this.focusTargetFor(focusField)
    if (!target) return

    requestAnimationFrame(() => {
      this.adjustScrollForStickyHeader()
      target.focus()
      target.select?.()
    })
  }

  focusTargetFor(focusField) {
    switch (focusField) {
      case "counterpart":
        return this.hasCounterpartTarget ? this.counterpartTarget : null
      case "description":
        return this.hasDescriptionTarget ? this.descriptionTarget : null
      case "amount":
        return this.hasAmountTarget ? this.amountTarget : null
      case "recorded_on":
        return this.hasRecordedOnTarget ? this.recordedOnTarget : null
      default:
        return this.hasCounterpartTarget ? this.counterpartTarget : null
    }
  }

  adjustScrollForStickyHeader() {
    const navbar = document.querySelector(".top-navbar")
    const headerHeight = navbar ? navbar.getBoundingClientRect().height : 0
    const topOffset = headerHeight + 8
    const rect = this.element.getBoundingClientRect()

    if (rect.top >= topOffset) return

    const targetTop = window.scrollY + rect.top - topOffset
    window.scrollTo({ top: Math.max(targetTop, 0), behavior: "auto" })
  }
}
