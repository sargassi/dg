class CreateRails < ActiveRecord::Migration[7.0]
  def change
    create_table :prodrow do |t|
      t.string :prodrow
      t.references :prodcode, null: false, foreign_key: true
      t.references :area, null: false, foreign_key: true
      t.integer :user
      t.integer :pub, default: 0

      t.timestamps
    end
  end
end
