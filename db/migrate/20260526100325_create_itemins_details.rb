class CreateIteminsDetails < ActiveRecord::Migration[7.2]
  def change
    create_table :itemins_details do |t|
      t.references :itemin, null: false, foreign_key: true
      t.string :itemcode
      t.integer :qty

      t.timestamps
    end
  end
end
