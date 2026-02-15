import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "nextBalance"]
  static values = { currentBalance: Number }

  connect() {
    this.recalculate()
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
}
