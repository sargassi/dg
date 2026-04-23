class ItemSerializer < ActiveModel::Serializer
  attributes :id, :itemcode, :"fabricode.string", :varcode, :description, :tg, :note, :fabric, :colour, :unit_price, :materiale
end
