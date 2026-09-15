import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "wrapper", "bg" ]

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
      canvas.width = 20
      canvas.height = 20
      const ctx = canvas.getContext('2d')
      
      // Draw image onto canvas for sampling
      ctx.drawImage(img, 0, 0, 20, 20)
      
      const imgData = ctx.getImageData(0, 0, 20, 20).data
      let r = 0, g = 0, b = 0, count = 0
      
      // Sample pixels across the canvas, filtering out near-white or extreme bright pixels
      for (let i = 0; i < imgData.length; i += 16) {
        const pr = imgData[i]
        const pg = imgData[i + 1]
        const pb = imgData[i + 2]
        
        const brightness = (pr * 299 + pg * 587 + pb * 114) / 1000
        if (brightness < 240) {
          r += pr
          g += pg
          b += pb
          count++
        }
      }
      
      if (count > 0) {
        r = Math.round(r / count)
        g = Math.round(g / count)
        b = Math.round(b / count)
      } else {
        r = 15; g = 23; b = 42
      }
      
      // Tone down brightness for smooth dark theme harmony
      const darkR = Math.max(8, Math.round(r * 0.35))
      const darkG = Math.max(12, Math.round(g * 0.35))
      const darkB = Math.max(22, Math.round(b * 0.35))
      
      const midR = Math.max(15, Math.round(r * 0.65))
      const midG = Math.max(20, Math.round(g * 0.65))
      const midB = Math.max(35, Math.round(b * 0.65))

      const primaryRgb = `rgb(${darkR}, ${darkG}, ${darkB})`
      const gradientBg = `linear-gradient(135deg, rgb(${darkR}, ${darkG}, ${darkB}) 0%, rgb(${midR}, ${midG}, ${midB}) 60%, #0b0f19 100%)`
      
      if (this.hasWrapperTarget) {
        this.wrapperTarget.style.setProperty('--banner-bg-color', primaryRgb)
        this.wrapperTarget.style.backgroundColor = primaryRgb
      }
      
      if (this.hasBgTarget) {
        this.bgTarget.style.background = gradientBg
      }
    } catch (e) {
      console.warn("Could not extract banner color due to cross-origin or canvas error:", e)
      if (this.hasWrapperTarget) {
        this.wrapperTarget.style.setProperty('--banner-bg-color', '#0b0f19')
        this.wrapperTarget.style.backgroundColor = '#0b0f19'
      }
    }
  }
}

