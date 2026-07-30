import { Controller } from "@hotwired/stimulus"

// Fills a datetime-local field with a date some number of days or years out, at
// 5pm local time. Each button carries its own offset so the set of offered
// durations stays in the template.
//
//   <div data-controller="quick-expire">
//     <button data-action="quick-expire#set" data-quick-expire-days-param="7">1 week</button>
//     <button data-action="quick-expire#set" data-quick-expire-years-param="1">1 year</button>
//     <input type="datetime-local" data-quick-expire-target="field">
//   </div>
export default class extends Controller {
  static targets = ["field"]

  set({ params: { days, years } }) {
    const date = new Date()

    if (years) {
      date.setFullYear(date.getFullYear() + years)
    } else {
      date.setDate(date.getDate() + days)
    }
    date.setHours(17, 0, 0, 0)

    this.fieldTarget.value = this._localDatetimeValue(date)
  }

  // datetime-local wants the wall-clock time, so toISOString is wrong here — it
  // would shift the value by the UTC offset.
  _localDatetimeValue(date) {
    const pad = (n) => String(n).padStart(2, "0")

    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
           `T${pad(date.getHours())}:${pad(date.getMinutes())}`
  }
}
