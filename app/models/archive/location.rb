module Archive
  class Location < ApplicationRecord
    has_many :items, class_name: "Archive::Item", foreign_key: :archive_location_id, dependent: :restrict_with_error
    belongs_to :parent, class_name: "Archive::Location", optional: true
    has_many :children, class_name: "Archive::Location", foreign_key: :parent_id, dependent: :nullify

    validates :code, presence: true, uniqueness: { scope: :parent_id }

    scope :sectors, -> { where(parent_id: nil) }

    def settore
      parent
    end

    def full_name
      parent ? "#{parent.code} > #{code}" : code
    end
    after_create_commit :generate_qr_code
    before_update :regenerate_qr, if: :code_changed?

    def gencode
      "arch_loc_#{id}_#{code}"
    end

    def generate_qr_code
      update_columns(qrcode_svg: RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end

    def regenerate_qr
      self.qrcode_svg = RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, "")
    end

    def to_s
      code
    end
  end
end
