class Inventory < ApplicationRecord
  belongs_to :warehouse
  belongs_to :location, optional: true
  belongs_to :operationtype
  belongs_to :itemin, foreign_key: :itemins_id, optional: true
  belongs_to :itemout, foreign_key: :itemouts_id, optional: true
end
