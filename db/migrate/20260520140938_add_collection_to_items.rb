class AddCollectionToItems < ActiveRecord::Migration[7.2]
  def change
    add_reference :items, :collection, null: true, foreign_key: true
  end
end
