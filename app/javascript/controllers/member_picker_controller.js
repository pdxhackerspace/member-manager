import { Controller } from "@hotwired/stimulus"

// Multi-select member picker. Pairs with the live-filter controller declared on
// the same element: live-filter owns the search box and which results are
// visible, this owns selection — the hidden inputs the form submits, the badge
// list, and the "Added" marker on each result row.
//
// The hidden inputs are the source of truth, so a form redisplayed after a
// validation failure keeps its selections without any extra server-side markup.
//
//   <div data-controller="live-filter member-picker"
//        data-live-filter-min-length-value="2"
//        data-member-picker-field-name-value="model[member_ids][]">
export default class extends Controller {
  static targets = ["search", "selected", "inputs", "result", "empty", "template"]
  static values = { fieldName: String }

  connect() {
    this.selectedTarget.replaceChildren()
    this._hiddenInputs().forEach((input) => {
      this.selectedTarget.appendChild(this._badge(input.value, input.dataset.userName || input.value))
    })
    this._sync()
  }

  add({ params }) {
    const id = String(params.id)
    if (this._selectedIds().has(id)) return

    const input = document.createElement("input")
    input.type = "hidden"
    input.name = this.fieldNameValue
    input.value = id
    input.dataset.userName = params.name
    this.inputsTarget.appendChild(input)

    this.selectedTarget.appendChild(this._badge(id, params.name))
    this._sync()
    this._resetSearch()
  }

  remove({ params }) {
    const id = String(params.id)

    this._hiddenInputs().forEach((input) => { if (input.value === id) input.remove() })
    this.selectedTarget
      .querySelectorAll(`[data-user-id="${CSS.escape(id)}"]`)
      .forEach((badge) => badge.remove())

    this._sync()
  }

  _badge(id, name) {
    const badge = this.templateTarget.content.firstElementChild.cloneNode(true)

    badge.dataset.userId = id
    badge.querySelector("[data-member-name]").textContent = name
    badge.querySelector("button").dataset.memberPickerIdParam = id

    return badge
  }

  // The always-present blank input lets the form clear every selection; it is
  // never a real member.
  _hiddenInputs() {
    return Array.from(this.inputsTarget.querySelectorAll("input[type=hidden]"))
      .filter((input) => input.value !== "")
  }

  _selectedIds() {
    return new Set(this._hiddenInputs().map((input) => input.value))
  }

  _sync() {
    const selected = this._selectedIds()

    this.resultTargets.forEach((row) => {
      const added = selected.has(row.dataset.userId)
      row.classList.toggle("opacity-50", added)
      row.querySelector("[data-member-added]")?.classList.toggle("d-none", !added)
    })

    this.emptyTarget.classList.toggle("d-none", selected.size > 0)
  }

  _resetSearch() {
    this.searchTarget.value = ""
    // Hands control of result visibility back to live-filter rather than
    // hiding the list here.
    this.searchTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.searchTarget.focus()
  }
}
