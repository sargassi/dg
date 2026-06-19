class CreateInventoriesFromItemmovement
  def call(itemmovement)
    records = []
    item_ids = itemmovement.itemmovements_details.map(&:item_id).compact.uniq
    items = Item.where(id: item_ids).index_by(&:id)

    itemmovement.itemmovements_details.each do |detail|
      gencode = items[detail.item_id]&.gencode

      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        operationtype_id: 2,
        itemmovement_id: itemmovement.id,
        enabled: true
      )

      StockLevel.upsert({
        gencode: gencode,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id || 0,
        current_qty: Arel.sql("COALESCE(current_qty, 0) - #{detail.qty.to_i}")
      }, unique_by: [:gencode, :warehouse_id, :location_id])

      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: itemmovement.dest_warehouse_id,
        location_id: itemmovement.dest_location_id,
        operationtype_id: 1,
        itemmovement_id: itemmovement.id,
        enabled: true
      )

      StockLevel.upsert({
        gencode: gencode,
        warehouse_id: itemmovement.dest_warehouse_id,
        location_id: itemmovement.dest_location_id || 0,
        current_qty: Arel.sql("COALESCE(current_qty, 0) + #{detail.qty.to_i}")
      }, unique_by: [:gencode, :warehouse_id, :location_id])
    end
    records
  end
end
