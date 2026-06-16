class CreateItemmovementsDetails < ActiveRecord::Migration[7.2]
  def change
    create_table :itemmovements_details do |t|
      t.references :itemmovement, null: false, foreign_key: true
      t.string :itemcode
      t.integer :qty
      t.integer :item_id
      t.integer :collection_id

      t.timestamps
    end
  end
end
