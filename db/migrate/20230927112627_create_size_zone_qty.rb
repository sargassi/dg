class CreateSizeZoneQty < ActiveRecord::Migration[7.0]
  def change
    create_table :size_zone_qties do |t|
      t.references :size, null: false, foreign_key: true
      t.references :zone, null: false, foreign_key: true

      t.timestamps
    end
  end
end
