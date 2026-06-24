import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "content", "button" ]
  static values = {
    expanded: { type: Boolean, default: false },
    collapsedLabel: { type: String, default: "More" },
    expandedLabel: { type: String, default: "Less" }
  }

  connect() {
    this.render()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.render()
  }

  render() {
    this.contentTarget.classList.toggle("is-expanded", this.expandedValue)

    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = this.expandedValue ? this.expandedLabelValue : this.collapsedLabelValue
    }
  }
}
