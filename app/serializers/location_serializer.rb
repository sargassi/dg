class LocationSerializer < ActiveModel::Serializer
  attributes :id, :code, :enabled
  has_one :warehouse
end
