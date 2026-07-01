class CreateInventoriesFromItemin
  def call(itemin)
    records = []
    item_ids = itemin.itemins_details.map(&:item_id).compact.uniq
    items = Item.where(id: item_ids).index_by(&:id)
    qr_service = CreateQrService.new

    itemin.itemins_details.each do |detail|
      gencode = items[detail.item_id]&.gencode
      qr_code = "#{gencode}_#{format('%04d', (detail.collection_id || 0).to_i)}_#{detail.id}"
      qr_svg = qr_service.svg(qr_code)

      records << Inventory.create!(
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        operationtype_id: detail.operationtype_id,
        itemins_id: itemin.id,
        qrcode_svg: qr_svg,
        enabled: true
      )

      StockLevel.adjust_qty!(gencode, detail.warehouse_id, detail.location_id, detail.qty.to_i)
    end
    records
  end
end
