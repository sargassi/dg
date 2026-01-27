class CreateFabriclus < ActiveRecord::Migration[7.0]
  def change
    create_table :fabriclus do |t|
      t.string :fab
      t.string :var
      t.integer :year
      t.text :description
      t.text :note
      t.text :tg
      t.text :color
      t.integer :qty
      t.string :materiale
      t.string :customer
      t.string :supplier

      t.timestamps
    end
  end
end
