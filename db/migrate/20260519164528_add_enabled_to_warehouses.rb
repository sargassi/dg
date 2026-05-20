class AddEnabledToWarehouses < ActiveRecord::Migration[7.2]
  def change
    add_column :warehouses, :enabled, :boolean , default: true
  end
end
