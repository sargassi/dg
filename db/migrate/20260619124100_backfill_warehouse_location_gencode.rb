class BackfillWarehouseLocationGencode < ActiveRecord::Migration[7.2]
  def up
    Warehouse.find_each { |w| w.update_columns(gencode: "#{w.id}_#{w.code}") }
    Location.find_each  { |l| l.update_columns(gencode: "#{l.warehouse_id}_#{l.id}_#{l.code}") }
  end

  def down
    Warehouse.update_all(gencode: nil)
    Location.update_all(gencode: nil)
  end
end
