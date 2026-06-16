class AddWarehouseLocationToItemmovementsDetails < ActiveRecord::Migration[7.2]
  def change
    add_column :itemmovements_details, :warehouse_id, :integer
    add_column :itemmovements_details, :location_id, :integer
  end
end
