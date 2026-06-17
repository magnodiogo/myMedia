import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "grid", "simpleBtn", "detailedBtn", "sliderContainer", "slider" ]

  connect() {
    const savedView = localStorage.getItem("media-view-preference") || "detailed"
    this.applyView(savedView)
  }

  setSimple() {
    this.applyView("simple")
  }

  setDetailed() {
    this.applyView("detailed")
  }

  applyView(view) {
    localStorage.setItem("media-view-preference", view)

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
}
