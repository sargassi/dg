class CreateInventoriesFromItemin
  def call(itemin)
    records = []
    item_ids = itemin.itemins_details.map(&:item_id).compact.uniq
    items = Item.where(id: item_ids).index_by(&:id)

    itemin.itemins_details.each do |detail|
      gencode = items[detail.item_id]&.gencode
      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        operationtype_id: detail.operationtype_id,
        itemins_id: itemin.id,
        enabled: true
      )
    end
    records
  end
end
