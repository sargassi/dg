class CreateArchiveItems < ActiveRecord::Migration[7.2]
  def change
    create_table :archive_items do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.references :archive_category, foreign_key: true
      t.references :archive_location, foreign_key: true
      t.string :status, default: "in", null: false
      t.text :notes
      t.text :qrcode_svg

      t.timestamps
    end
    add_index :archive_items, :code, unique: true
  end
end
