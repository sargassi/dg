module API
  module V1
    module Entities
      class InventoryDetail < Grape::Entity
        expose :gencode
        expose :current_qty
        expose :warehouse_id
        expose :location_id
        expose :warehouse, using: API::V1::Entities::WarehouseSimple, if: { type: :full }
        expose :location, using: API::V1::Entities::LocationSimple, if: { type: :full }
      end

      class WarehouseSimple < Grape::Entity
        expose :id, :code
      end

      class LocationSimple < Grape::Entity
        expose :id, :code
      end
    end
  end
end
