class Inventory < ApplicationRecord
  belongs_to :warehouse
  belongs_to :location
  belongs_to :operationtype
  belongs_to :itemin
  belongs_to :itemout
end
