class AddWarehouseLocationOperationToItemins < ActiveRecord::Migration[7.2]
  def change
    add_column :itemins, :warehouse_id, :integer
    add_column :itemins, :location_id, :integer
    add_column :itemins, :operationtype_id, :integer
  end
end
