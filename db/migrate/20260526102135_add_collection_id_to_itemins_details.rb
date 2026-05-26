class AddCollectionIdToIteminsDetails < ActiveRecord::Migration[7.2]
  def change
    add_column :itemins_details, :collection_id, :integer
  end
end
