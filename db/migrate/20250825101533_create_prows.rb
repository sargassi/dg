class CreateProws < ActiveRecord::Migration[7.0]
  def change
    create_table :prows do |t|
      t.text :code
      t.references :proforma, null: false, foreign_key: true
      t.text :description
      t.text :note
      t.integer :qty
      t.text :qr

      t.timestamps
    end
  end
end
