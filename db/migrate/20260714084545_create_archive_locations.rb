class CreateArchiveLocations < ActiveRecord::Migration[7.2]
  def change
    create_table :archive_locations do |t|
      t.string :code, null: false
      t.text :description
      t.boolean :enabled, default: true, null: false
      t.text :qrcode_svg

      t.timestamps
    end
    add_index :archive_locations, :code, unique: true
  end
end
