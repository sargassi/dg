class CreateRassegna < ActiveRecord::Migration[7.0]
  def change
    create_table :rassegnas do |t|
      t.string :titolo
      t.string :tipologia
      t.integer :anno
      t.string :paese
      t.string :medium
      t.string :testata
      t.string :pagine
      t.text   :descrizione
      t.string :giornalista
      t.string :photo
      t.boolean :salva
      t.timestamps
    end
  end
end
