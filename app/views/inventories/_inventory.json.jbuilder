json.extract! inventory, :id, :qtyavailable, :minstock, :maxstock, :warehouse_id, :location_id, :itemcode, :operationtype_id, :itemins_id, :itemouts_id, :enabled, :created_at, :updated_at
json.url inventory_url(inventory, format: :json)
