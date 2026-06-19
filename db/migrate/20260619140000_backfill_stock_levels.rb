class BackfillStockLevels < ActiveRecord::Migration[7.2]
  def up
    Inventory.select(:gencode, :warehouse_id, :location_id)
      .select(Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty"))
      .group(:gencode, :warehouse_id, :location_id)
      .having("net_qty != 0")
      .each do |row|
        StockLevel.upsert(
          { gencode: row.gencode, warehouse_id: row.warehouse_id, location_id: row.location_id || 0, current_qty: row.net_qty },
          unique_by: [:gencode, :warehouse_id, :location_id]
        )
      end
  end

  def down
    StockLevel.delete_all
  end
end
