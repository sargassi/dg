class Item < ApplicationRecord
  belongs_to :collection, optional: true
  before_save :rebuild_gencode
  before_save :regenerate_qr, if: :gencode_changed?

  def self.ransackable_attributes(auth_object = nil)
         ["itemcode", "varcode", "description", "tg", "fabric", "colour", "unit_price", "materiale", "note"]
  end

  def self.ransackable_associations(auth_object = nil)
         []
  end

  has_many_attached :pictures

  private

  def rebuild_gencode
    self.gencode = [itemcode, fabricode, varcode].map(&:to_s).join + "_#{collection_id}"
  end

  def regenerate_qr
    require 'rqrcode'
    self.qrcode_svg = RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, "")
  end
end
