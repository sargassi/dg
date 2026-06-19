class CreateStockLevels < ActiveRecord::Migration[7.2]
  def change
    create_table :stock_levels do |t|
      t.string  :gencode,       null: false
      t.integer :warehouse_id,  null: false
      t.integer :location_id,   null: false, default: 0
      t.integer :current_qty,   null: false, default: 0
      t.timestamps
    end

    add_index :stock_levels, [:gencode, :warehouse_id, :location_id],
              unique: true,
              name: "idx_stock_levels_unique"
    add_index :stock_levels, :gencode
    add_index :stock_levels, :warehouse_id
  end
end
