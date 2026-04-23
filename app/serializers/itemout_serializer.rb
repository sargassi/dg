class ItemoutSerializer < ActiveModel::Serializer
  attributes :id, :indate
  has_one :operator
end
