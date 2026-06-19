class Warehouse < ApplicationRecord
  has_many :locations, dependent: :destroy
  validates :code, presence: true, uniqueness: true
  after_create_commit :generate_qr_code
  before_update :regenerate_qr, if: :code_changed?

  def generate_qr_code
    require 'rqrcode'
    self.gencode = "#{id}_#{code}"
    update_columns(gencode: self.gencode, qrcode_svg: RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
  end

  def regenerate_qr
    self.gencode = "#{id}_#{code}"
    self.qrcode_svg = RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, "")
  end
end
