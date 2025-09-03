class AddFabricToEtilab < ActiveRecord::Migration[7.0]
  def change
    add_column :etilabs, :fabric, :string
  end
end
