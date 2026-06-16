import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "video", "preview", "input", "confirmBtn", "counter", "flash", "summary"];

  connect() {
    this.photos = [];
    this.stream = null;

    window.__cameraPending = window.__cameraPending || [];
    this._pendingPhotos = window.__cameraPending;
    if (this._pendingPhotos.length > 0) this._renderSummary();

    this._boundBeforeFetch = this._injectPhotos.bind(this);
    this._boundBeforeVisit = () => { window.__cameraPending = []; };
    document.addEventListener("turbo:before-fetch-request", this._boundBeforeFetch);
    document.addEventListener("turbo:before-visit", this._boundBeforeVisit);
  }

  disconnect() {
    document.removeEventListener("turbo:before-fetch-request", this._boundBeforeFetch);
    document.removeEventListener("turbo:before-visit", this._boundBeforeVisit);
    this._stopCamera();
  }

  async open(event) {
    event.preventDefault();
    this.photos = [];
    this._renderPreview();
    if (this.hasConfirmBtnTarget) this.confirmBtnTarget.classList.add("hidden");
    this._updateCounter();
    this.modalTarget.classList.remove("hidden");
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment", width: { ideal: 1920 }, height: { ideal: 1080 } },
      });
      this.videoTarget.srcObject = this.stream;
      await this.videoTarget.play();
    } catch (e) {
      alert("Impossibile accedere alla fotocamera: " + e.message);
    }
  }

  close() {
    this._stopCamera();
    this.modalTarget.classList.add("hidden");
    this.photos = [];
    this._renderPreview();
    if (this.hasConfirmBtnTarget) this.confirmBtnTarget.classList.add("hidden");
    this._updateCounter();
  }

  _stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach((t) => t.stop());
      this.stream = null;
    }
    if (this.videoTarget) this.videoTarget.srcObject = null;
  }

  shoot() {
    const canvas = document.createElement("canvas");
    canvas.width = this.videoTarget.videoWidth || 640;
    canvas.height = this.videoTarget.videoHeight || 480;
    canvas.getContext("2d").drawImage(this.videoTarget, 0, 0);

    this._flash();

    canvas.toBlob((blob) => {
      this.photos.push(blob);
      this._addPreview(blob);
      this._updateCounter();
      this.confirmBtnTarget.classList.remove("hidden");
    }, "image/jpeg", 0.85);
  }

  _flash() {
    if (!this.hasFlashTarget) return;
    this.flashTarget.classList.remove("hidden");
    setTimeout(() => this.flashTarget.classList.add("hidden"), 150);
  }

  _updateCounter() {
    if (!this.hasCounterTarget) return;
    const n = this.photos.length;
    this.counterTarget.textContent = n === 0 ? "" : `${n} foto scattat${n === 1 ? "a" : "e"}`;
  }

  _addPreview(blob) {
    const wrapper = this._thumbnailWrapper(blob, (b, el) => {
      const idx = this.photos.indexOf(b);
      if (idx !== -1) this.photos.splice(idx, 1);
      el.remove();
      this._updateCounter();
      if (this.photos.length === 0) this.confirmBtnTarget.classList.add("hidden");
    });
    this.previewTarget.appendChild(wrapper);
  }

  _renderPreview() {
    if (this.hasPreviewTarget) this.previewTarget.innerHTML = "";
  }

  confirm() {
    if (this.photos.length === 0) return;

    this._pendingPhotos.push(...this.photos);
    this.photos = [];
    this._renderPreview();
    if (this.hasConfirmBtnTarget) this.confirmBtnTarget.classList.add("hidden");
    this._updateCounter();
    this._renderSummary();
    this.close();
  }

  _renderSummary() {
    this.summaryTarget.innerHTML = "";
    if (this._pendingPhotos.length === 0) {
      this.summaryTarget.classList.add("hidden");
      return;
    }

    this._pendingPhotos.forEach((blob) => {
      const wrapper = this._thumbnailWrapper(blob, (b, el) => {
        const idx = this._pendingPhotos.indexOf(b);
        if (idx !== -1) this._pendingPhotos.splice(idx, 1);
        el.remove();
        if (this._pendingPhotos.length === 0) this.summaryTarget.classList.add("hidden");
      });
      this.summaryTarget.appendChild(wrapper);
    });
    this.summaryTarget.classList.remove("hidden");
  }

  _thumbnailWrapper(blob, onRemove) {
    const url = URL.createObjectURL(blob);

    const wrapper = document.createElement("div");
    wrapper.className = "relative group";

    const img = document.createElement("img");
    img.src = url;
    img.className = "w-16 h-16 object-cover rounded border border-slate-200";

    const del = document.createElement("button");
    del.type = "button";
    del.className =
      "absolute -top-1.5 -right-1.5 w-4 h-4 bg-red-500 text-white rounded-full flex items-center justify-center text-[10px] leading-none opacity-0 group-hover:opacity-100 transition cursor-pointer";
    del.textContent = "×";
    del.addEventListener("click", () => onRemove(blob, wrapper));

    wrapper.appendChild(img);
    wrapper.appendChild(del);
    return wrapper;
  }

  _injectPhotos(event) {
    if (event.target !== this.element) return;
    if (this._pendingPhotos.length === 0) return;

    const formData = event.detail.fetchOptions.body;
    this._pendingPhotos.forEach((blob, i) => {
      formData.append("item[pictures][]", blob, `camera_${i}.jpg`);
    });
  }
}
