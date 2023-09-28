class AddQtyToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :qty, :string
  end
end
