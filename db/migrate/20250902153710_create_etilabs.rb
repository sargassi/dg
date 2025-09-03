class CreateEtilabs < ActiveRecord::Migration[7.0]
  def change
    create_table :etilabs do |t|
      t.string :itemcode
      t.string :fabricode
      t.string :varcode
      t.string :description
      t.string :tg
      t.string :color
      t.integer :qty
      t.string :materiale
      t.integer :group
      t.string :customer
      t.string :supplier

      t.timestamps
    end
  end
end
