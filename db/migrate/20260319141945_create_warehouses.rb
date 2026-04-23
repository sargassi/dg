class CreateWarehouses < ActiveRecord::Migration[7.0]
  def change
    create_table :warehouses do |t|
      t.string :code
      t.string :address
      t.string :city
      t.string :cap
      t.string :civic
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end
