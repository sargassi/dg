import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { anchor: String }

  connect() {
    console.log('[highlight-source] Connecting')
    console.log('[highlight-source] Element:', this.element)
    console.log('[highlight-source] Anchor value:', this.anchorValue)
    console.log('[highlight-source] All elements with prow-:', document.querySelectorAll('[id^="prow-"]'))
    
    if (this.anchorValue) {
      this.highlightRow()
    }
  }

  highlightRow() {
    console.log('[highlight-source] Looking for:', this.anchorValue)
    
    const row = document.getElementById(this.anchorValue)
    console.log('[highlight-source] Found row:', row)
    
    if (row) {
      row.classList.add('row-highlight')
      setTimeout(() => row.classList.remove('row-highlight'), 2000)
    } else {
      console.log('[highlight-source] Row not found, checking sessionStorage')
      const stored = sessionStorage.getItem('highlightRowOnClose')
      if (stored) {
        const storedRow = document.getElementById(stored)
        if (storedRow) {
          storedRow.classList.add('row-highlight')
          setTimeout(() => storedRow.classList.remove('row-highlight'), 2000)
        }
      }
    }
  }
}