import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "fabBtn", 
    "fabMenu", 
    "barcodeModal", 
    "searchModal",
    "searchTitle",
    "searchArtist",
    "searchFormatId",
    "searchButton",
    "searchStatus",
    "searchResults",
    "doneButton"
  ]

  static values = {
    admin: Boolean
  }

  connect() {
    this.selectedItems = []
  }

  toggleMenu() {
    if (this.hasFabMenuTarget) this.fabMenuTarget.classList.toggle("active")
    if (this.hasFabBtnTarget) this.fabBtnTarget.classList.toggle("active")
  }

  openBarcodeModal() {
    this.closeMenu()
    this.barcodeModalTarget.classList.add("active")
  }

  closeBarcodeModal() {
    this.barcodeModalTarget.classList.remove("active")
  }

  openSearchModal() {
    this.closeMenu()
    this.selectedItems = []
    this.updateDoneButton()
    this.searchModalTarget.classList.add("active")
  }

  closeSearchModal() {
    this.searchModalTarget.classList.remove("active")
  }

  closeMenu() {
    if (this.hasFabMenuTarget) this.fabMenuTarget.classList.remove("active")
    if (this.hasFabBtnTarget) this.fabBtnTarget.classList.remove("active")
  }

  async performSearch(event) {
    if (event) event.preventDefault()

    const title = this.searchTitleTarget.value.trim()
    const artist = this.searchArtistTarget.value.trim()

    if (!title && !artist) {
      this.showSearchStatus("Please enter a title or artist.", "danger")
      return
    }

    this.selectedItems = []
    this.updateDoneButton()

    this.searchButtonTarget.disabled = true
    this.searchButtonTarget.innerHTML = `<span class="spinner-sm" style="display: inline-block; width: 12px; height: 12px; border: 2px solid #fff; border-top-color: transparent; border-radius: 50%; animation: submit-spin 0.8s linear infinite; margin-right: 0.5rem;"></span> Searching...`
    this.searchResultsTarget.innerHTML = `<p style="color: var(--text-muted); text-align: center; padding: 2rem 0;">Searching for results...</p>`

    try {
      const response = await fetch(`/media/global_search?title=${encodeURIComponent(title)}&artist=${encodeURIComponent(artist)}`)
      if (!response.ok) {
        throw new Error("Server search error")
      }
      
      const results = await response.json()
      this.renderResults(results)
    } catch (e) {
      console.error(e)
      this.showSearchStatus("Error conducting search. Please try again.", "danger")
      this.searchResultsTarget.innerHTML = ""
    } finally {
      this.searchButtonTarget.disabled = false
      this.searchButtonTarget.innerHTML = "🔍 Search Collection & Online"
    }
  }

  renderResults(results) {
    this.searchStatusTarget.innerHTML = ""
    if (results.length === 0) {
      this.searchResultsTarget.innerHTML = `
        <p style="color: var(--text-muted); text-align: center; padding: 2rem 0;">
          No results found. You can add items manually using the menu button.
        </p>
      `
      return
    }

    this.searchResultsTarget.innerHTML = ""
    results.forEach(item => {
      const row = document.createElement("div")
      row.className = "search-result-row"

      const coverSrc = item.cover_url || "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='50' height='50'><rect width='50' height='50' fill='%23141a2d'/><text x='50%25' y='50%25' font-size='20' dominant-baseline='middle' text-anchor='middle'>🎵</text></svg>"
      const sourceBadgeClass = item.source === "Local Catalog" ? "local" : "online"

      // Build row HTML
      row.innerHTML = `
        <img class="search-result-cover" src="${coverSrc}" alt="Cover">
        <div class="search-result-details">
          <div class="search-result-title" title="${item.title}">${item.title}</div>
          <div class="search-result-artist" title="${item.artist}">${item.artist}</div>
          <div class="search-result-meta">
            <span class="source-badge ${sourceBadgeClass}">${item.source}</span>
            <span style="font-size: 0.8rem; color: var(--text-muted);">${item.release_year || "Year N/A"}</span>
          </div>
        </div>
        <div class="search-result-action"></div>
      `

      const actionContainer = row.querySelector(".search-result-action")

      if (item.owned) {
        const ownedLabel = document.createElement("span")
        ownedLabel.className = "source-badge local"
        ownedLabel.style.padding = "0.35rem 0.65rem"
        ownedLabel.style.borderRadius = "20px"
        ownedLabel.textContent = "✓ Owned"
        actionContainer.appendChild(ownedLabel)
      } else {
        if (!this.adminValue && item.source !== "Local Catalog") {
          const restrictedLabel = document.createElement("span")
          restrictedLabel.className = "source-badge"
          restrictedLabel.style.backgroundColor = "rgba(239, 68, 68, 0.15)"
          restrictedLabel.style.border = "1px solid rgba(239, 68, 68, 0.3)"
          restrictedLabel.style.color = "#fca5a5"
          restrictedLabel.style.fontSize = "0.75rem"
          restrictedLabel.style.padding = "0.25rem 0.5rem"
          restrictedLabel.style.borderRadius = "12px"
          restrictedLabel.textContent = "Admin Only"
          actionContainer.appendChild(restrictedLabel)
        } else {
          const checkboxLabel = document.createElement("label")
          checkboxLabel.className = "custom-checkbox-wrapper"

          const checkbox = document.createElement("input")
          checkbox.type = "checkbox"
          checkbox.className = "custom-checkbox-input"
          checkbox.addEventListener("change", (e) => this.toggleItemSelection(e, item))

          const checkmark = document.createElement("span")
          checkmark.className = "custom-checkbox-checkmark"

          checkboxLabel.appendChild(checkbox)
          checkboxLabel.appendChild(checkmark)
          actionContainer.appendChild(checkboxLabel)
        }
      }

      this.searchResultsTarget.appendChild(row)
    })
  }

  toggleItemSelection(event, item) {
    const checkbox = event.target
    if (checkbox.checked) {
      this.selectedItems.push(item)
    } else {
      this.selectedItems = this.selectedItems.filter(i => {
        if (item.id) {
          return i.id !== item.id
        } else {
          return !(i.title === item.title && i.artist === item.artist)
        }
      })
    }
    this.updateDoneButton()
  }

  updateDoneButton() {
    if (!this.hasDoneButtonTarget) return
    const count = this.selectedItems.length
    if (count === 0) {
      this.doneButtonTarget.innerHTML = "Done"
      this.doneButtonTarget.classList.remove("btn-glow")
    } else {
      this.doneButtonTarget.innerHTML = `Done (Import ${count} ${count === 1 ? 'item' : 'items'})`
      this.doneButtonTarget.classList.add("btn-glow")
    }
  }

  async submitSelection(event) {
    if (event) event.preventDefault()

    const count = this.selectedItems.length
    if (count === 0) {
      this.closeSearchModal()
      return
    }

    this.doneButtonTarget.disabled = true
    this.doneButtonTarget.innerHTML = `<span class="spinner-sm" style="display: inline-block; width: 12px; height: 12px; border: 2px solid #fff; border-top-color: transparent; border-radius: 50%; animation: submit-spin 0.8s linear infinite; margin-right: 0.5rem;"></span> Importing ${count}...`

    const formatId = this.hasSearchFormatIdTarget ? this.searchFormatIdTarget.value : null
    let errors = []

    for (const item of this.selectedItems) {
      try {
        if (item.id) {
          // Local add
          const response = await fetch(`/media/${item.id}/add_to_collection`, {
            method: "POST",
            headers: {
              "X-CSRF-Token": this.getCsrfToken(),
              "Content-Type": "application/json"
            }
          })
          if (!response.ok) {
            errors.push(`Failed to add: ${item.title}`)
          }
        } else {
          // Online import
          const response = await fetch(`/media/import_and_add`, {
            method: "POST",
            headers: {
              "X-CSRF-Token": this.getCsrfToken(),
              "Content-Type": "application/json"
            },
            body: JSON.stringify({
              title: item.title,
              artist: item.artist,
              release_year: item.release_year,
              media_type_id: formatId,
              cover_url: item.cover_url
            })
          })
          if (!response.ok) {
            const errData = await response.json()
            errors.push(`Failed to import ${item.title}: ${errData.error || 'Server error'}`)
          }
        }
      } catch (e) {
        console.error(e)
        errors.push(`Network error for: ${item.title}`)
      }
    }

    this.doneButtonTarget.disabled = false
    this.updateDoneButton()

    if (errors.length > 0) {
      alert(`Finished with errors:\n${errors.join("\n")}`)
    }

    window.location.reload()
  }

  showSearchStatus(message, type) {
    let color = type === "danger" ? "#fca5a5" : "#a5b4fc"
    let bg = type === "danger" ? "rgba(239, 68, 68, 0.1)" : "rgba(99, 102, 241, 0.1)"
    let border = type === "danger" ? "rgba(239, 68, 68, 0.2)" : "rgba(99, 102, 241, 0.2)"

    this.searchStatusTarget.innerHTML = `
      <div style="padding: 0.75rem 1rem; border-radius: 6px; color: ${color}; background-color: ${bg}; border: 1px solid ${border}; font-size: 0.85rem; margin-bottom: 1rem; display: flex; align-items: center; gap: 0.5rem;">
        ${message}
      </div>
    `
  }

  getCsrfToken() {
    return document.querySelector("[name='csrf-token']").getAttribute("content")
  }

  flashNotice(msg) {
    console.log("Notice:", msg)
  }

  flashAlert(msg) {
    alert(msg)
  }
}
