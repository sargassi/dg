class EticheckSerializer < ActiveModel::Serializer
  attributes :id, :itemcode, :fabricode, :varcode, :group, :description, :tg, :fabric, :qt, :materiale, :chi, :dove, :cspediti
end
