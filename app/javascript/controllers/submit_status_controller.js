import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal", "submitButton", "validationStep", "imageStep", "saveStep" ]

  connect() {
    this.handleSubmitStart = this.handleSubmitStart.bind(this)
    this.handleSubmitEnd = this.handleSubmitEnd.bind(this)
    
    this.element.addEventListener("turbo:submit-start", this.handleSubmitStart)
    this.element.addEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.handleSubmitStart)
    this.element.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
    if (this.timeoutId) clearTimeout(this.timeoutId)
    if (this.timeoutId2) clearTimeout(this.timeoutId2)
  }

  handleSubmitStart(event) {
    // Disable submit button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("disabled")
    }

    // Show modal
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("active")
    }

    // Reset step styles
    this.resetSteps()

    // Start steps sequence
    this.runStepsSequence()
  }

  handleSubmitEnd(event) {
    // Called if form submission fails (e.g., validation error resulting in 422 status)
    if (!event.detail.success) {
      if (this.hasModalTarget) {
        this.modalTarget.classList.remove("active")
      }
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.classList.remove("disabled")
      }
      if (this.timeoutId) clearTimeout(this.timeoutId)
      if (this.timeoutId2) clearTimeout(this.timeoutId2)
    }
  }

  resetSteps() {
    const steps = [this.validationStepTarget, this.imageStepTarget, this.saveStepTarget]
    steps.forEach(step => {
      if (step) {
        step.className = "step-pending"
        const icon = step.querySelector(".step-icon")
        if (icon) {
          icon.textContent = "⏳"
          icon.classList.remove("spinning")
        }
      }
    })
  }

  runStepsSequence() {
    // Step 1: Validating details
    this.setStepActive(this.validationStepTarget)

    this.timeoutId = setTimeout(() => {
      this.setStepComplete(this.validationStepTarget)

      // Check if we need image processing (either a file was selected, or a cover URL is entered)
      const fileInput = this.element.querySelector('input[type="file"][name*="cover_image"]')
      const urlInput = this.element.querySelector('input[type="hidden"][name*="cover_url"]')
      const hasFile = fileInput && fileInput.files && fileInput.files.length > 0
      const hasUrl = urlInput && urlInput.value && urlInput.value.trim() !== ""
      const hasImage = hasFile || hasUrl

      if (hasImage) {
        // Step 2: Processing image
        this.setStepActive(this.imageStepTarget)

        this.timeoutId2 = setTimeout(() => {
          this.setStepComplete(this.imageStepTarget)
          // Step 3: Saving to database
          this.setStepActive(this.saveStepTarget)
        }, 1000) // Wait 1 second to show the image resize progress
      } else {
        // Skip image step
        this.setStepSkipped(this.imageStepTarget)
        // Step 3: Saving to database
        this.setStepActive(this.saveStepTarget)
      }
    }, 500)
  }

  setStepActive(target) {
    if (!target) return
    target.className = "step-active"
    const icon = target.querySelector(".step-icon")
    if (icon) {
      icon.textContent = "🔄"
      icon.classList.add("spinning")
    }
  }

  setStepComplete(target) {
    if (!target) return
    target.className = "step-complete"
    const icon = target.querySelector(".step-icon")
    if (icon) {
      icon.textContent = "✓"
      icon.classList.remove("spinning")
    }
  }

  setStepSkipped(target) {
    if (!target) return
    target.className = "step-skipped"
    const icon = target.querySelector(".step-icon")
    if (icon) {
      icon.textContent = "➖"
      icon.classList.remove("spinning")
    }
  }
}
