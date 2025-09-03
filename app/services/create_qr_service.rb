class CreateQrService
  require 'rqrcode'

  def call(code)
    qr = RQRCode::QRCode.new(code)

    qrpng = qr.as_png(
      bit_depth: 1,
      border_modules: 0,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: "black",
      file: nil,
      fill: "white",
      module_px_size: 6,
      resize_exactly_to: false,
      resize_gte_to: false,
      size: 120
    )



  end
end
