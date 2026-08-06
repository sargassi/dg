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
    new_qty = (sl.current_qty || 0) + delta
    raise InsufficientStockError, "Stock negativo per #{gencode}" if new_qty.negative?

    sl.current_qty = new_qty
    sl.save!
  end

  class InsufficientStockError < StandardError; end
end
