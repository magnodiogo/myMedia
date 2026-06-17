import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal", "frame", "title" ]

  connect() {
    this.closeOnEscapeBind = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.closeOnEscapeBind)
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscapeBind)
  }

  open(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.url
    const trackTitle = event.currentTarget.dataset.trackTitle

    if (this.hasTitleTarget) {
      this.titleTarget.textContent = `Edit Lyrics - ${trackTitle}`
    }

    if (this.hasFrameTarget) {
      this.frameTarget.src = url
    }

    if (this.hasModalTarget) {
      this.modalTarget.classList.add("active")
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("active")
    }

    if (this.hasFrameTarget) {
      this.frameTarget.removeAttribute("src")
      this.frameTarget.innerHTML = '<p style="color: var(--text-muted); text-align: center; padding: 2rem 0;">Loading...</p>'
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
