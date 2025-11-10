// script.js file

function domReady(fn) {
    if (
        document.readyState === "complete" ||
        document.readyState === "interactive"
    ) {
        setTimeout(fn, 1000);
    } else {
        document.addEventListener("DOMContentLoaded", fn);
    }
}

function play(){
   const audio = new Audio('ok.mp3')
   audio.loop = false
   audio.play()
}

domReady(function () {

    // If found you qr code
    function onScanSuccess(decodeText, decodeResult) {
         let input = document.getElementById('input')
         console.log(document.readyState)
         input.value = decodeText
         play()
         input.classList.add('success')    
         
         //alert("You Qr is : " + decodeText, decodeResult);
    }

    let htmlscanner = new Html5QrcodeScanner(
        "qr-reader",
        { fps: 10, qrbos: 250 }
    );
    htmlscanner.render(onScanSuccess);
});