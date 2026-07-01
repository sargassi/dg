class StockLevel < ApplicationRecord
  belongs_to :warehouse
  belongs_to :location, optional: true

  scope :positive, -> { where("current_qty > 0") }

  def self.adjust_qty!(gencode, warehouse_id, location_id, delta)
    raise ArgumentError, "gencode cannot be nil" if gencode.nil?
    sl = find_or_initialize_by(
      gencode: gencode,
      warehouse_id: warehouse_id,
      location_id: location_id || 0
    )
    sl.current_qty = (sl.current_qty || 0) + delta
    sl.save!
  end
end
