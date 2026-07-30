class InventoryCreator
  def call(movement)
    case movement
    when Itemin  then create_for(movement, type: :inbound)
    when Itemout then create_for(movement, type: :outbound)
    else raise ArgumentError, "Unsupported movement type: #{movement.class}"
    end
  end

  private

  def create_for(movement, type:)
    detail_assoc = MovementBuilder::DETAIL_ASSOCIATIONS[movement.class]
    details = movement.send(detail_assoc)
    generate_qr = (type == :inbound)
    delta = (type == :inbound) ? 1 : -1

    records = []
    item_ids = details.map(&:item_id).compact.uniq
    items = Item.where(id: item_ids).index_by(&:id)
    qr_service = CreateQrService.new if generate_qr

    details.each do |detail|
      gencode = items[detail.item_id]&.gencode

      inv_attrs = {
        itemcode: detail.itemcode,
        gencode: gencode,
        item_id: detail.item_id,
        qtyavailable: detail.qty,
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        operationtype_id: detail.operationtype_id,
        enabled: true
      }

      if movement.is_a?(Itemin)
        inv_attrs[:itemins_id] = movement.id
        qr_code = "#{gencode}_#{format('%04d', (detail.collection_id || 0).to_i)}_#{detail.id}"
        inv_attrs[:qrcode_svg] = qr_service.svg(qr_code)
      elsif movement.is_a?(Itemout)
        inv_attrs[:itemouts_id] = movement.id
      end

      records << Inventory.create!(inv_attrs)
      StockLevel.adjust_qty!(gencode, detail.warehouse_id, detail.location_id, detail.qty.to_i * delta)
    end

    records
  end
end
