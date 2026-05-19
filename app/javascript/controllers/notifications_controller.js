import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="notifications"
// macOS-style bottom-right toast with slide-in animation and auto-dismiss.
//
// Usage:
//   <div data-controller="notifications"
//        data-notifications-auto-dismiss-value="4000">
//     ...
//   </div>
//
// The element should start with translate-x-full opacity-0 (off-screen right).
// On connect it slides in; after autoDismiss ms it slides out and removes itself.
export default class extends Controller {
  static values = { autoDismiss: { type: Number, default: 4000 } };

  connect() {
    // Trigger slide-in from the right on next paint
    requestAnimationFrame(() => {
      this.element.classList.remove("translate-x-full", "opacity-0");
    });

    // Schedule auto-dismiss
    this.timeout = setTimeout(() => this.dismiss(), this.autoDismissValue);
  }

  dismiss() {
    // Slide out to the right
    this.element.classList.add("translate-x-full", "opacity-0");
    // Remove from DOM after transition completes (matches duration-300)
    setTimeout(() => this.element.remove(), 300);
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout);
  }
}
