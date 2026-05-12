class ItemSerializer < ActiveModel::Serializer
  attributes :id, :itemcode, :fabricode, :varcode, :description, :tg, :note, :fabric, :colour, :unit_price, :materiale
end
