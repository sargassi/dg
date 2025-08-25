class CreateStations < ActiveRecord::Migration[7.0]
  def change
    create_table :stations do |t|
      t.text :description
      t.text :note

      t.timestamps
    end
  end
end
