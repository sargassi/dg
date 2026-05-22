class CreateAbilities < ActiveRecord::Migration[7.2]
  def change
    create_table :abilities do |t|
      t.string :name,        null: false
      t.string :description
      t.string :category
      t.timestamps
    end
    add_index :abilities, :name, unique: true
  end
end
