class AddItemIdToIteminsDetails < ActiveRecord::Migration[7.2]
  def change
    add_column :itemins_details, :item_id, :integer
  end
end
