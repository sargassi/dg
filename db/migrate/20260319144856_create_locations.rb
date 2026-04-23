class CreateLocations < ActiveRecord::Migration[7.0]
  def change
    create_table :locations do |t|
      t.string :code
      t.references :warehouse, null: false, foreign_key: true
      t.boolean :enabled

      t.timestamps
    end
  end
end
