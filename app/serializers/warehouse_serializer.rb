class WarehouseSerializer < ActiveModel::Serializer
  attributes :id, :code, :address, :city, :cap, :civic, :latitude, :longitude
end
