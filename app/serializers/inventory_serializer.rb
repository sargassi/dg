class InventorySerializer < ActiveModel::Serializer
  attributes :id, :qtyavailable, :minstock, :maxstock, :itemcode, :enabled
  has_one :warehouse
  has_one :location
  has_one :operationtype
  has_one :itemins
  has_one :itemouts
end
