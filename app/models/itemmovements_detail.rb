class ItemmovementsDetail < ApplicationRecord
  belongs_to :itemmovement
  belongs_to :item, optional: true
end
