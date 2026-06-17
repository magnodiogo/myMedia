import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "grid", "simpleBtn", "detailedBtn" ]

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
    } else {
      this.gridTarget.classList.remove("grid-simple")
      this.detailedBtnTarget.classList.add("active")
      this.simpleBtnTarget.classList.remove("active")
    }
  }
}
