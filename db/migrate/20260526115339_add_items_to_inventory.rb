class AddItemsToInventory < ActiveRecord::Migration[7.2]
  def change
    add_reference :inventories, :item, foreign_key: true
  end
end
