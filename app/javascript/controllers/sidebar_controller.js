import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "icon" ]

  toggle() {
    const isCollapsed = this.element.classList.toggle("sidebar-collapsed")
    
    if (this.hasIconTarget) {
      this.iconTarget.textContent = isCollapsed ? "▶" : "◀"
    }

    this.savePreference({ sidebar_collapsed: isCollapsed })
  }

  toggleMobile() {
    this.element.classList.toggle("sidebar-mobile-open")
  }

  savePreference(params) {
    const csrfToken = document.querySelector("[name='csrf-token']").getAttribute("content")
    const queryString = new URLSearchParams(params).toString()
    
    fetch(`/preferences?${queryString}`, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      }
    }).catch(err => console.error("Failed to save preferences:", err))
  }
}
