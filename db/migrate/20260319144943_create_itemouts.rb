class CreateItemouts < ActiveRecord::Migration[7.0]
  def change
    create_table :itemouts do |t|
      t.date :indate
      t.references :operator, null: false, foreign_key: true

      t.timestamps
    end
  end
end
