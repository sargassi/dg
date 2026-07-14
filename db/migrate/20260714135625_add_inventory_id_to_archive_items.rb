class AddInventoryIdToArchiveItems < ActiveRecord::Migration[7.2]
  def change
    add_reference :archive_items, :inventory, foreign_key: true, null: true
  end
end
