class AddQtyToTempesta < ActiveRecord::Migration[7.0]
  def change
    add_column :tempesta, :qty, :integer, default: 1
  end
end
