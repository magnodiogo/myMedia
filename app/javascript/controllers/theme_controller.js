import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button" ]

  connect() {
    const isLight = document.documentElement.classList.contains("light-theme")
    this.updateButtonText(isLight ? "light" : "dark")
  }

  toggle() {
    const isLight = document.documentElement.classList.toggle("light-theme")
    const theme = isLight ? "light" : "dark"
    this.updateButtonText(theme)
    this.savePreference({ theme: theme })
  }

  updateButtonText(theme) {
    if (this.hasButtonTarget) {
      if (theme === "light") {
        this.buttonTarget.innerHTML = `<span class="nav-icon">🌙</span> <span class="theme-toggle-text">Dark Mode</span>`
      } else {
        this.buttonTarget.innerHTML = `<span class="nav-icon">☀️</span> <span class="theme-toggle-text">Light Mode</span>`
      }
    }
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
