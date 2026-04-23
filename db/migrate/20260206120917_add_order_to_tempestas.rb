class AddOrderToTempestas < ActiveRecord::Migration[7.0]
  def change
    add_column :tempesta, :order, :integer, default: 1
  end
end
