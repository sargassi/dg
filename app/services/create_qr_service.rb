class CreateQrService
  require 'rqrcode'

  MODULE_SIZE = 6
  SVG_OPTIONS = { module_size: MODULE_SIZE, use_path: true, viewbox: true, standalone: true }.freeze

  def call(code)
    qr = RQRCode::QRCode.new(code)

    qr.as_png(
      bit_depth: 1,
      border_modules: 0,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: "black",
      file: nil,
      fill: "white",
      module_px_size: MODULE_SIZE,
      resize_exactly_to: false,
      resize_gte_to: false,
      size: 120
    )
  end

  def svg(code)
    qr = RQRCode::QRCode.new(code)
    qr.as_svg(**SVG_OPTIONS).sub(/^<\?xml[^>]*>/, "")
  end
end
