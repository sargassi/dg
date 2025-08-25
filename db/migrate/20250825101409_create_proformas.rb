class CreateProformas < ActiveRecord::Migration[7.0]
  def change
    create_table :proformas do |t|
      t.text :customer
      t.time :data_in
      t.time :data_out
      t.boolean :closed
      t.text :note

      t.timestamps
    end
  end
end
