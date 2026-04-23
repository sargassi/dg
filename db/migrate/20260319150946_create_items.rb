class CreateItems < ActiveRecord::Migration[7.0]
  def change
    create_table :items do |t|
      t.string :itemcode
      t.string :fabricode
      t.string :varcode
      t.string :description
      t.string :tg
      t.text :note
      t.string :fabric
      t.string :colour
      t.decimal :unit_price
      t.string :materiale

      t.timestamps
    end
  end
end
