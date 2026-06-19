class AddGencodeToWarehousesAndLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :warehouses, :gencode, :string
    add_column :locations,  :gencode, :string
    add_index :warehouses, :gencode
    add_index :locations,  :gencode
  end
end
