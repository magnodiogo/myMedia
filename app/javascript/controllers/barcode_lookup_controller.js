import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "query", 
    "title", 
    "artist", 
    "year", 
    "catalog", 
    "barcode", 
    "coverUrl", 
    "preview", 
    "status", 
    "searchButton"
  ]

  async lookup(event) {
    if (event) event.preventDefault()

    const barcodeVal = this.queryTarget.value.trim().replace(/[-\s]/g, "")
    if (!barcodeVal) {
      this.showStatus("Please enter a barcode number.", "danger")
      return
    }

    this.setLoading(true)
    this.showStatus("🔍 Searching for barcode...", "info")

    try {
      const response = await fetch(`/media/barcode_lookup?barcode=${barcodeVal}`)
      if (!response.ok) {
        if (response.status === 404) {
          this.showStatus("❌ Barcode not found online. You can type the details manually below.", "warning")
        } else {
          this.showStatus("⚠️ Search failed on server. You can still input manually.", "danger")
        }
        return
      }

      const data = await response.json()
      
      const title = data.title || ""
      const artist = data.artist || ""
      const year = data.year || ""
      const catalog = data.catalog || ""
      const coverUrl = data.cover_url || ""

      this.fillForm({ title, artist, year, catalog, barcode: barcodeVal, coverUrl })
      this.showStatus(`✅ Found on ${data.source}! Album details autofilled.`, "success")
    } catch (error) {
      console.error("Barcode lookup error:", error)
      this.showStatus("⚠️ Search failed due to network error. You can still input manually.", "danger")
    } finally {
      this.setLoading(false)
    }
  }

  fillForm({ title, artist, year, catalog, barcode, coverUrl }) {
    if (title && this.hasTitleTarget) {
      this.titleTarget.value = title
      this.triggerFlash(this.titleTarget)
    }
    if (artist && this.hasArtistTarget) {
      this.artistTarget.value = artist
      this.triggerFlash(this.artistTarget)
    }
    if (year && this.hasYearTarget) {
      this.yearTarget.value = year
      this.triggerFlash(this.yearTarget)
    }
    if (catalog && this.hasCatalogTarget) {
      this.catalogTarget.value = catalog
      this.triggerFlash(this.catalogTarget)
    }
    if (barcode && this.hasBarcodeTarget) {
      this.barcodeTarget.value = barcode
      this.triggerFlash(this.barcodeTarget)
    }

    if (coverUrl && this.hasCoverUrlTarget) {
      this.coverUrlTarget.value = coverUrl
      this.showCoverPreview(coverUrl)
    }

    // Automatically reveal the confirmation metadata form and hide helper
    const metaForm = document.getElementById("barcode-metadata-form")
    if (metaForm) metaForm.style.display = "block"
    const manualHelper = document.getElementById("barcode-manual-helper")
    if (manualHelper) manualHelper.style.display = "none"
  }

  showCoverPreview(url) {
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = `
        <div class="cover-preview-box">
          <img src="${url}" class="cover-preview-image" />
          <span class="cover-preview-text">Cover loaded from barcode database (resizing to 600x600 on save)</span>
        </div>
      `
    }
  }

  triggerFlash(element) {
    element.classList.remove("highlight-autofill")
    // Force reflow to restart animation
    void element.offsetWidth
    element.classList.add("highlight-autofill")
  }

  setLoading(isLoading) {
    if (this.hasSearchButtonTarget) {
      this.searchButtonTarget.disabled = isLoading
      this.searchButtonTarget.innerHTML = isLoading 
        ? `<span class="spinner-sm" style="display: inline-block; width: 12px; height: 12px; border: 2px solid #fff; border-top-color: transparent; border-radius: 50%; animation: submit-spin 0.8s linear infinite; margin-right: 0.5rem;"></span> Searching...`
        : `🔍 Lookup Barcode`
    }
  }

  showStatus(message, type) {
    if (!this.hasStatusTarget) return

    let color = "var(--text-muted)"
    let bg = "rgba(255, 255, 255, 0.02)"
    let border = "rgba(255, 255, 255, 0.05)"

    if (type === "success") {
      color = "#a7f3d0"
      bg = "rgba(16, 185, 129, 0.1)"
      border = "rgba(16, 185, 129, 0.2)"
    } else if (type === "warning") {
      color = "#fde047"
      bg = "rgba(234, 179, 8, 0.1)"
      border = "rgba(234, 179, 8, 0.2)"
    } else if (type === "danger") {
      color = "#fca5a5"
      bg = "rgba(239, 68, 68, 0.1)"
      border = "rgba(239, 68, 68, 0.2)"
    } else if (type === "info") {
      color = "#a5b4fc"
      bg = "rgba(99, 102, 241, 0.1)"
      border = "rgba(99, 102, 241, 0.2)"
    }

    this.statusTarget.innerHTML = `
      <div style="padding: 0.75rem 1rem; border-radius: 6px; color: ${color}; background-color: ${bg}; border: 1px solid ${border}; font-size: 0.85rem; line-height: 1.4; display: flex; align-items: center; gap: 0.5rem; animation: fadeIn 0.3s ease;">
        ${message}
      </div>
    `
  }
}
