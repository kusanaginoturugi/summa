import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["code", "name"]
  static values = { accountsMap: Object }

  connect() {
    this.entries = Object.entries(this.accountsMapValue || {})
    this.sortedEntries = this.entries.slice().sort((a, b) => a[0].localeCompare(b[0], "ja", { numeric: true }))
    this.isComposing = false
    this.onCompositionStart = () => {
      this.isComposing = true
    }
    this.onCompositionEnd = (event) => {
      this.isComposing = false
      this.update(event)
    }
    this.element.addEventListener("compositionstart", this.onCompositionStart, true)
    this.element.addEventListener("compositionend", this.onCompositionEnd, true)
  }

  disconnect() {
    this.element.removeEventListener("compositionstart", this.onCompositionStart, true)
    this.element.removeEventListener("compositionend", this.onCompositionEnd, true)
  }

  update(event) {
    if (this.isComposing && event?.type !== "compositionend") return
    if (event?.isComposing) return

    const input = event?.target
    const code = input ? input.value.trim() : this.codeTarget.value.trim()
    const name = this.lookup(code) || ""
    const nameTarget = input?.closest(".input-group")?.querySelector("[data-account-lookup-target='name']")
    if (nameTarget) {
      nameTarget.textContent = name
      this.suggest(event)
      return
    }
    if (this.hasNameTarget) this.nameTarget.textContent = name
    this.suggest(event)
  }

  lookup(code) {
    if (!code) return null
    return (this.accountsMapValue || {})[code] || null
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

    if (!this.entries || this.entries.length === 0) {
      return
    }

    const raw = input.value.trim()
    const keyword = this.normalizeDigits(raw)
    const lower = raw.toLowerCase()
    let matches = this.sortedEntries || this.entries

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
