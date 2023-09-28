class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products do |t|
      t.string :prodcode
      t.string :itemcode
      t.string :fabricode
      t.string :varcode
      t.text :description
      t.string :tg
      t.text :note
      t.string :fabric
      t.string :color
      t.string :materiale

      t.timestamps
    end
  end
end
