import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "wrapper" ]

  connect() {
    if (this.hasImageTarget) {
      // Ensure crossOrigin is set to allow canvas pixel reading on same-origin/configured CORS
      this.imageTarget.crossOrigin = "anonymous"
      
      if (this.imageTarget.complete) {
        this.extractColor()
      } else {
        this.imageTarget.addEventListener('load', () => this.extractColor())
      }
    }
  }

  extractColor() {
    try {
      const img = this.imageTarget
      const canvas = document.createElement('canvas')
      canvas.width = 10
      canvas.height = 10
      const ctx = canvas.getContext('2d')
      
      // Draw image to a 10x10 canvas to average the edges
      ctx.drawImage(img, 0, 0, 10, 10)
      
      // Sample the left edge (column 0, row 5) and right edge (column 9, row 5)
      const leftPixel = ctx.getImageData(0, 5, 1, 1).data
      const rightPixel = ctx.getImageData(9, 5, 1, 1).data
      
      // Average the two sampled edge pixels
      const r = Math.round((leftPixel[0] + rightPixel[0]) / 2)
      const g = Math.round((leftPixel[1] + rightPixel[1]) / 2)
      const b = Math.round((leftPixel[2] + rightPixel[2]) / 2)
      
      const rgb = `rgb(${r}, ${g}, ${b})`
      
      if (this.hasWrapperTarget) {
        this.wrapperTarget.style.backgroundColor = rgb
      }
    } catch (e) {
      console.warn("Could not extract banner border color due to cross-origin or canvas error:", e)
      // Fallback to a dark color if color extraction fails (e.g. CORS block on external CDNs)
      if (this.hasWrapperTarget) {
        this.wrapperTarget.style.backgroundColor = "#0b0f19"
      }
    }
  }
}
