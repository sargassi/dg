class CreateInventories < ActiveRecord::Migration[7.0]
  def change
    create_table :inventories do |t|
      t.integer :qtyavailable
      t.integer :minstock
      t.integer :maxstock
      t.references :warehouse, null: false, foreign_key: true
      t.references :location, null: true, foreign_key: true
      t.string :itemcode
      t.references :operationtype, null: false, foreign_key: true
      t.references :itemins, null: true, foreign_key: true
      t.references :itemouts, null: true, foreign_key: true
      t.boolean :enabled, default: true

      t.timestamps
    end
  end
end
