class CreateItemmovements < ActiveRecord::Migration[7.2]
  def change
    create_table :itemmovements do |t|
      t.date :indate
      t.text :notes
      t.integer :operator_id
      t.integer :source_warehouse_id
      t.integer :source_location_id
      t.integer :dest_warehouse_id
      t.integer :dest_location_id

      t.timestamps
    end
  end
end
