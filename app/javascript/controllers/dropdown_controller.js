import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu" ]

  connect() {
    this.closeBind = this.close.bind(this)
    document.addEventListener("click", this.closeBind)
  }

  disconnect() {
    document.removeEventListener("click", this.closeBind)
  }

  toggle(event) {
    event.stopPropagation()
    event.preventDefault()
    
    // Close other dropdowns first
    document.querySelectorAll(".context-menu-dropdown.active").forEach(el => {
      if (el !== this.menuTarget) {
        el.classList.remove("active")
      }
    })

    this.menuTarget.classList.toggle("active")
  }

  close(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      this.menuTarget.classList.remove("active")
    }
  }
}
