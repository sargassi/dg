class CreateEtichecks < ActiveRecord::Migration[7.2]
  def change
    create_table :etichecks do |t|
      t.string :itemcode
      t.string :fabricode
      t.string :varcode
      t.integer :group, default: 1
      t.string :description
      t.string :tg
      t.string :fabric
      t.integer :qt, default: 1
      t.string :materiale
      t.string :chi
      t.string :dove
      t.string :cspediti

      t.timestamps
    end
  end
end
