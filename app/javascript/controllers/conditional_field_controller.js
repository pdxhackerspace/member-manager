import { Controller } from "@hotwired/stimulus"

// Reveals a dependent field only while a <select> holds a particular value, and
// keeps `required` in sync with that visibility. The two must move together: a
// hidden input carrying `required` makes the browser refuse to submit while
// reporting the problem somewhere the user cannot see.
//
//   <div data-controller="conditional-field" data-conditional-field-match-value="other">
//     <select data-conditional-field-target="trigger"
//             data-action="change->conditional-field#toggle">
//     <div data-conditional-field-target="field" class="d-none">
//       <input data-conditional-field-target="input">
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["trigger", "field", "input"]
  static values = { match: String }

  connect() {
    this.toggle()
  }

  toggle() {
    const show = this.triggerTarget.value === this.matchValue

    this.fieldTarget.classList.toggle("d-none", !show)
    this.inputTargets.forEach((input) => { input.required = show })
  }
}
