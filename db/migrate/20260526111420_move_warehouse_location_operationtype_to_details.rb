class MoveWarehouseLocationOperationtypeToDetails < ActiveRecord::Migration[7.2]
  def change
    remove_column :itemins, :warehouse_id, :integer
    remove_column :itemins, :location_id, :integer
    remove_column :itemins, :operationtype_id, :integer

    remove_column :itemouts, :warehouse_id, :integer
    remove_column :itemouts, :location_id, :integer
    remove_column :itemouts, :operationtype_id, :integer

    add_column :itemins_details, :warehouse_id, :integer
    add_column :itemins_details, :location_id, :integer
    add_column :itemins_details, :operationtype_id, :integer

    add_column :itemouts_details, :warehouse_id, :integer
    add_column :itemouts_details, :location_id, :integer
    add_column :itemouts_details, :operationtype_id, :integer
  end
end
