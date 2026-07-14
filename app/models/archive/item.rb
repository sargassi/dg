module Archive
  class Item < ApplicationRecord
    belongs_to :category, class_name: "Archive::Category", foreign_key: :archive_category_id, optional: true
    belongs_to :location, class_name: "Archive::Location", foreign_key: :archive_location_id, optional: true
    belongs_to :inventory, optional: true
    belongs_to :source_item, class_name: "Item", optional: true
    has_many :transactions, class_name: "Archive::Transaction", foreign_key: :archive_item_id, dependent: :destroy
    has_many_attached :pictures

    validates :name, presence: true
    validates :code, uniqueness: true, allow_nil: true
    before_create :generate_code
    after_create_commit :generate_qr_code
    before_update :regenerate_qr, if: :code_changed?

    scope :in_stock, -> { where(status: "in") }
    scope :checked_out, -> { where(status: "out") }
    scope :by_category, ->(id) { where(archive_category_id: id) if id.present? }
    scope :by_location, ->(id) { where(archive_location_id: id) if id.present? }
    scope :by_status, ->(s) { where(status: s) if s.present? }
    scope :search, ->(q) {
      return all if q.blank?
      pattern = "%#{q}%"
      where("code LIKE :q OR name LIKE :q OR description LIKE :q OR notes LIKE :q", q: pattern)
    }

    private

    def generate_code
      last = self.class.maximum(:code)
      next_num = if last
                   last.split("-").last.to_i + 1
                 else
                   1
                 end
      self.code = format("ARC-%04d", next_num)
    end

    def generate_qr_code
      update_columns(qrcode_svg: RQRCode::QRCode.new(code).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end

    def regenerate_qr
      self.qrcode_svg = RQRCode::QRCode.new(code).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, "")
    end
  end
end
