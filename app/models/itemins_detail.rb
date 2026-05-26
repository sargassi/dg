class IteminsDetail < ApplicationRecord
  belongs_to :itemin
  belongs_to :warehouse
  belongs_to :location, optional: true
  belongs_to :operationtype
  belongs_to :item, optional: true

  validates :warehouse, presence: true
end
