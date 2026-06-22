import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "grid", "simpleBtn", "detailedBtn", "sliderContainer", "slider" ]

  connect() {
    if (this.hasGridTarget) {
      const isSimple = this.gridTarget.classList.contains("grid-simple")
      if (isSimple) {
        this.changeSize()
      }
    }
  }

  setSimple() {
    this.applyView("simple")
  }

  setDetailed() {
    this.applyView("detailed")
  }

  applyView(view) {
    this.savePreference({ view_preference: view })

    if (view === "simple") {
      this.gridTarget.classList.add("grid-simple")
      this.simpleBtnTarget.classList.add("active")
      this.detailedBtnTarget.classList.remove("active")
      if (this.hasSliderContainerTarget) {
        this.sliderContainerTarget.style.display = "flex"
      }
      this.changeSize()
    } else {
      this.gridTarget.classList.remove("grid-simple")
      this.detailedBtnTarget.classList.add("active")
      this.simpleBtnTarget.classList.remove("active")
      if (this.hasSliderContainerTarget) {
        this.sliderContainerTarget.style.display = "none"
      }
      this.gridTarget.style.removeProperty('--simple-card-size')
    }
  }

  changeSize() {
    if (this.hasSliderTarget && this.hasGridTarget) {
      const val = this.sliderTarget.value
      this.gridTarget.style.setProperty('--simple-card-size', `${val}px`)
    }
  }

  saveSize() {
    if (this.hasSliderTarget) {
      const val = this.sliderTarget.value
      this.savePreference({ media_card_size: val })
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
