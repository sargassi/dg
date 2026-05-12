import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log('[highlight-row] Controller connected')
    this.highlightRow()
    
    document.addEventListener('turbo:frame-load', () => {
      console.log('[highlight-row] Frame loaded, checking row')
      this.highlightRow()
    })
  }

  highlightRow() {
    const hash = window.location.hash
    let rowId = null
    
    if (hash && hash.startsWith('#prow-')) {
      rowId = hash.replace('#prow-', '')
    } else {
      const stored = sessionStorage.getItem('highlightRow')
      if (stored) {
        rowId = stored.replace('prow-', '')
      }
    }
    
    console.log('[highlight-row] Row ID:', rowId)
    
    if (rowId) {
      const row = document.getElementById(`prow-${rowId}`)
      console.log('[highlight-row] Found row:', row)
      
      if (row) {
        row.classList.add('border-4', 'border-blue-500')
        setTimeout(() => {
          row.classList.remove('border-4', 'border-blue-500')
        }, 2000)
      }
    }
  }
}