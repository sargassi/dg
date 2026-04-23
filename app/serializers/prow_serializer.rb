class ProwSerializer < ActiveModel::Serializer
  attributes :id, :code, :description, :qty, :qr
end
