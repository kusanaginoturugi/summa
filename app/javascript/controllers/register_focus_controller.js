import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "description"]
  static values = { focusField: String }

  connect() {
    const focusTarget = this.resolveFocusTarget()
    if (!focusTarget) return

    requestAnimationFrame(() => {
      this.adjustScrollForStickyHeader()
      focusTarget.focus()
      focusTarget.select?.()
    })
  }

  resolveFocusTarget() {
    if (this.focusFieldValue === "description" && this.hasDescriptionTarget) {
      return this.descriptionTarget
    }
    if (this.hasInputTarget) return this.inputTarget
    if (this.hasDescriptionTarget) return this.descriptionTarget
    return null
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
