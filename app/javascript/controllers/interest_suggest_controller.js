import { Controller } from "@hotwired/stimulus"

// Autocomplete for the profile setup "Add New Interest" field. Selected interests
// are read from the pill cloud on each lookup so Turbo Stream toggles stay in sync.
export default class extends Controller {
  static targets = ["input", "suggestions", "form"]
  static values = { interests: Array }

  connect() {
    this._onTurboSubmitEnd = this._refreshSuggestions.bind(this)
    document.addEventListener("turbo:submit-end", this._onTurboSubmitEnd)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-end", this._onTurboSubmitEnd)
  }

  filter() {
    this._showSuggestions(this.inputTarget.value.toLowerCase().trim())
  }

  hideSuggestions() {
    setTimeout(() => {
      this.suggestionsTarget.style.display = "none"
    }, 150)
  }

  showSuggestionsIfPresent() {
    const query = this.inputTarget.value.toLowerCase().trim()
    if (query.length > 0) this._showSuggestions(query)
  }

  inputKeydown(event) {
    const items = this.suggestionsTarget.querySelectorAll(".list-group-item")
    if (!items.length) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      items[0].focus()
    } else if (event.key === "Escape") {
      this.suggestionsTarget.style.display = "none"
    }
  }

  suggestionsKeydown(event) {
    const items = Array.from(this.suggestionsTarget.querySelectorAll(".list-group-item"))
    const idx = items.indexOf(document.activeElement)

    if (event.key === "ArrowDown") {
      event.preventDefault()
      if (idx < items.length - 1) items[idx + 1].focus()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      if (idx > 0) items[idx - 1].focus()
      else this.inputTarget.focus()
    } else if (event.key === "Escape") {
      this.suggestionsTarget.style.display = "none"
      this.inputTarget.focus()
    } else if (event.key === "Enter") {
      event.preventDefault()
      items[idx].dispatchEvent(new MouseEvent("mousedown"))
    }
  }

  _refreshSuggestions(event) {
    if (!event.detail.success) return
    if (this.inputTarget.value.trim().length === 0) return

    this._showSuggestions(this.inputTarget.value.toLowerCase().trim())
  }

  _showSuggestions(query) {
    this.suggestionsTarget.innerHTML = ""
    if (query.length === 0) {
      this.suggestionsTarget.style.display = "none"
      return
    }

    const selectedIds = this._selectedInterestIds()
    const matches = this.interestsValue
      .filter((interest) => !selectedIds.has(interest.id) && interest.name.toLowerCase().startsWith(query))
      .slice(0, 10)

    if (matches.length === 0) {
      this.suggestionsTarget.style.display = "none"
      return
    }

    matches.forEach((interest) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "list-group-item list-group-item-action py-1 small"
      btn.textContent = interest.name
      btn.addEventListener("mousedown", (event) => {
        event.preventDefault()
        this.inputTarget.value = interest.name
        this.suggestionsTarget.style.display = "none"
        this.formTarget.requestSubmit()
      })
      this.suggestionsTarget.appendChild(btn)
    })

    this.suggestionsTarget.style.display = "block"
  }

  _selectedInterestIds() {
    const ids = []
    document.querySelectorAll('[id^="pill_interest_"]').forEach((pill) => {
      if (!pill.querySelector('form[action*="/remove"]')) return

      const id = parseInt(pill.id.replace("pill_interest_", ""), 10)
      if (!Number.isNaN(id)) ids.push(id)
    })
    return new Set(ids)
  }
}
