class Location < ApplicationRecord
  belongs_to :warehouse
  after_create_commit :generate_qr_code
  before_update :regenerate_qr, if: :code_changed?

  def generate_qr_code
    self.gencode = "#{warehouse_id}_#{id}_#{code}"
    update_columns(gencode: self.gencode, qrcode_svg: RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
  end

  def regenerate_qr
    self.gencode = "#{warehouse_id}_#{id}_#{code}"
    self.qrcode_svg = RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, "")
  end
end
