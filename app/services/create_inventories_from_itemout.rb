class CreateInventoriesFromItemout
  def call(itemout)
    records = []
    item_ids = itemout.itemouts_details.map(&:item_id).compact.uniq
    items = Item.where(id: item_ids).index_by(&:id)

    itemout.itemouts_details.each do |detail|
      gencode = items[detail.item_id]&.gencode
      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        operationtype_id: detail.operationtype_id,
        itemouts_id: itemout.id,
        enabled: true
      )

      StockLevel.adjust_qty!(gencode, detail.warehouse_id, detail.location_id, -detail.qty.to_i)
    end
    records
  end
end
