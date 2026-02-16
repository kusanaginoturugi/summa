import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (!this.hasInputTarget) return

    requestAnimationFrame(() => {
      this.adjustScrollForStickyHeader()
      this.inputTarget.focus()
      this.inputTarget.select()
    })
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
