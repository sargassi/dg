class IteminsDetail < ApplicationRecord
  belongs_to :itemin
  belongs_to :item, optional: true
  belongs_to :collection, optional: true
end