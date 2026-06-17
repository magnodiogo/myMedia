import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "artist", "title", "results", "urlInput", "preview" ]

  async search(event) {
    event.preventDefault()
    
    const artist = this.artistTarget.value.trim()
    const title = this.titleTarget.value.trim()

    if (!artist && !title) {
      alert("Please fill in the Artist or Title first.")
      return
    }

    this.resultsTarget.innerHTML = `<p style="color: var(--text-muted); font-size: 0.9rem; margin-top: 0.5rem;">Searching covers online...</p>`

    try {
      const searchTerm = encodeURIComponent(`${artist} ${title}`)
      const response = await fetch(`https://itunes.apple.com/search?term=${searchTerm}&entity=album&limit=6`)
      const data = await response.json()

      if (data.results && data.results.length > 0) {
        this.resultsTarget.innerHTML = ""
        
        const grid = document.createElement("div")
        grid.style.display = "grid"
        grid.style.gridTemplateColumns = "repeat(auto-fill, minmax(80px, 1fr))"
        grid.style.gap = "0.75rem"
        grid.style.marginTop = "0.75rem"

        data.results.forEach(album => {
          const thumbUrl = album.artworkUrl100
          // Get high-res cover (600x600) instead of the 100x100 thumbnail
          const highResUrl = thumbUrl.replace("100x100bb", "600x600bb")

          const itemContainer = document.createElement("div")
          itemContainer.style.display = "flex"
          itemContainer.style.flexDirection = "column"
          itemContainer.style.alignItems = "center"

          const imgWrapper = document.createElement("div")
          imgWrapper.className = "search-cover-thumb"
          imgWrapper.style.cursor = "pointer"
          imgWrapper.style.borderRadius = "6px"
          imgWrapper.style.overflow = "hidden"
          imgWrapper.style.border = "2px solid transparent"
          imgWrapper.style.transition = "all var(--transition-speed) ease"
          imgWrapper.style.width = "80px"
          imgWrapper.style.height = "80px"

          const img = document.createElement("img")
          img.src = thumbUrl
          img.style.width = "100%"
          img.style.height = "100%"
          img.style.objectFit = "cover"
          img.alt = album.collectionName
          img.title = `${album.artistName} - ${album.collectionName}`

          imgWrapper.appendChild(img)

          const infoLabel = document.createElement("div")
          infoLabel.style.fontSize = "0.7rem"
          infoLabel.style.textAlign = "center"
          infoLabel.style.color = "var(--text-muted)"
          infoLabel.style.marginTop = "0.25rem"
          infoLabel.style.lineHeight = "1.2"
          infoLabel.innerHTML = `600x600<br><span class="size-label" style="opacity: 0.8;">Loading...</span>`

          itemContainer.appendChild(imgWrapper)
          itemContainer.appendChild(infoLabel)

          // Asynchronously query file size
          this.getFileSize(highResUrl).then(size => {
            const sizeSpan = infoLabel.querySelector(".size-label")
            if (sizeSpan) {
              sizeSpan.textContent = size || "N/A"
            }
          })

          imgWrapper.addEventListener("click", () => {
            // Clear previous selections
            grid.querySelectorAll(".search-cover-thumb").forEach(el => el.style.borderColor = "transparent")
            // Highlight current selection
            imgWrapper.style.borderColor = "var(--accent-primary)"
            // Populate the hidden URL field
            this.urlInputTarget.value = highResUrl
            // Update the preview element
            this.showPreview(highResUrl)
          })

          grid.appendChild(itemContainer)
        })

        this.resultsTarget.appendChild(grid)
      } else {
        this.resultsTarget.innerHTML = `<p style="color: var(--text-muted); font-size: 0.9rem; margin-top: 0.5rem;">No covers found.</p>`
      }
    } catch (error) {
      console.error(error)
      this.resultsTarget.innerHTML = `<p style="color: var(--danger-color); font-size: 0.9rem; margin-top: 0.5rem;">Error loading covers. Please upload a file manually.</p>`
    }
  }

  showPreview(url) {
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = `
        <div style="margin-top: 0.5rem; display: flex; align-items: center; gap: 0.5rem;">
          <img src="${url}" style="width: 50px; height: 50px; object-fit: cover; border-radius: 4px; border: 1px solid var(--panel-border);" />
          <span style="font-size: 0.85rem; color: var(--text-muted);">Online cover selected (will download & resize to 600x600 on save)</span>
        </div>
      `
    }
  }

  async getFileSize(url) {
    try {
      const response = await fetch(url, { method: "HEAD" })
      const contentLength = response.headers.get("Content-Length")
      if (contentLength) {
        const bytes = parseInt(contentLength, 10)
        if (bytes > 1024 * 1024) {
          return `${(bytes / (1024 * 1024)).toFixed(2)} MB`
        } else {
          return `${(bytes / 1024).toFixed(1)} KB`
        }
      }
    } catch (e) {
      console.warn("Could not fetch image file size", e)
    }
    return null
  }
}
