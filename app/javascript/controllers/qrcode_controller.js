import { BrowserQRCodeReader } from "https://cdn.jsdelivr.net/npm/@zxing/library@0.21.3/+esm";
import { FetchRequest } from "@rails/request.js";

import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="qrcode"
export default class extends Controller {
  connect() {
    const codeReader = new BrowserQRCodeReader();
    codeReader
      .decodeFromInputVideoDevice(undefined, "video")
      .then((result) => {
        // process the result
        let qrDataFromReader = result.text;
        checkReq(result.text);
        // Prepare a post request so it can be sent to the Rails controller
        async function checkReq(string) {
          const request = new FetchRequest(
            "get",
            "/basic_qr_codes/qrcheck?key=" + string,
          );
          const response = await request.perform();
          if (response.ok) {
            const body = await response.text;
            // Do whatever do you want with the response body
            // You also are able to call `response.html` or `response.json`, be aware that if you call `response.json` and the response contentType isn't `application/json` there will be raised an error.
            console.log(body);
          }
        }
        document.getElementById("result").textContent = result.text;
      })
      .catch((err) => console.error(err));
  }
}
