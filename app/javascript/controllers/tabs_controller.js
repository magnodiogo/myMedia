import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "panel" ]

  connect() {
    const activeTab = this.tabTargets.find(t => t.classList.contains("active"))
    const activeTabId = activeTab ? activeTab.dataset.tabId : this.tabTargets[0]?.dataset.tabId

    if (activeTabId) {
      this.activate(activeTabId)
    }
  }

  switch(event) {
    event.preventDefault()
    const tabId = event.currentTarget.dataset.tabId
    this.activate(tabId)
  }

  activate(tabId) {
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tabId === tabId) {
        tab.classList.add("active")
      } else {
        tab.classList.remove("active")
      }
    })

    this.panelTargets.forEach(panel => {
      if (panel.dataset.tabId === tabId) {
        panel.style.display = "block"
      } else {
        panel.style.display = "none"
      }
    })
  }
}
