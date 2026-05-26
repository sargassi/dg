class CreateItemoutsDetails < ActiveRecord::Migration[7.2]
  def change
    create_table :itemouts_details do |t|
      t.references :itemout, null: false, foreign_key: true
      t.string :itemcode
      t.integer :qty
      t.integer :item_id
      t.integer :collection_id

      t.timestamps
    end
  end
end
