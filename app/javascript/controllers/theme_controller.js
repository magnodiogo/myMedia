import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button" ]

  connect() {
    const savedTheme = localStorage.getItem("theme") || "dark"
    this.setTheme(savedTheme)
  }

  toggle() {
    const currentTheme = document.documentElement.classList.contains("light-theme") ? "dark" : "light"
    this.setTheme(currentTheme)
  }

  setTheme(theme) {
    if (theme === "light") {
      document.documentElement.classList.add("light-theme")
      if (this.hasButtonTarget) {
        this.buttonTarget.innerHTML = `<span class="nav-icon">🌙</span> Dark Mode`
      }
    } else {
      document.documentElement.classList.remove("light-theme")
      if (this.hasButtonTarget) {
        this.buttonTarget.innerHTML = `<span class="nav-icon">☀️</span> Light Mode`
      }
    }
    localStorage.setItem("theme", theme)
  }
}
