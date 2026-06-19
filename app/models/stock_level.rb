class StockLevel < ApplicationRecord
  belongs_to :warehouse
  belongs_to :location, optional: true

  scope :positive, -> { where("current_qty > 0") }
end
