class InventoryCreator
  def call(movement)
    case movement
    when Itemin       then create_for(movement, type: :inbound)
    when Itemout      then create_for(movement, type: :outbound)
    when Itemmovement then create_for_movement(movement)
    else raise ArgumentError, "Unsupported movement type: #{movement.class}"
    end
  end

  private

  def details_for(movement)
    detail_assoc = MovementBuilder::DETAIL_ASSOCIATIONS[movement.class]
    movement.send(detail_assoc)
  end

  def items_by_id_for(details)
    item_ids = details.map(&:item_id).compact.uniq
    Item.where(id: item_ids).index_by(&:id)
  end

  def create_for(movement, type:)
    details = details_for(movement)
    items = items_by_id_for(details)
    generate_qr = (type == :inbound)
    delta = (type == :inbound) ? 1 : -1

    details.map do |detail|
      create_inventory_record(
        movement: movement,
        detail: detail,
        item: items[detail.item_id],
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        qty: detail.qty,
        operationtype_id: detail.operationtype_id,
        delta: delta,
        generate_qr: generate_qr
      )
    end
  end

  def create_for_movement(movement)
    details = details_for(movement)
    items = items_by_id_for(details)

    details.flat_map do |detail|
      source = create_inventory_record(
        movement: movement,
        detail: detail,
        item: items[detail.item_id],
        warehouse_id: detail.warehouse_id,
        location_id: detail.location_id,
        qty: detail.qty,
        operationtype_id: 2,
        delta: -1
      )

      dest = create_inventory_record(
        movement: movement,
        detail: detail,
        item: items[detail.item_id],
        warehouse_id: movement.dest_warehouse_id,
        location_id: movement.dest_location_id,
        qty: detail.qty,
        operationtype_id: 1,
        delta: 1
      )

      [source, dest]
    end
  end

  def create_inventory_record(movement:, detail:, item:, warehouse_id:, location_id:, qty:, operationtype_id:, delta:, generate_qr: false)
    gencode = item&.gencode

    inv_attrs = {
      itemcode: item&.itemcode || detail.itemcode,
      gencode: gencode,
      item_id: detail.item_id,
      qtyavailable: qty,
      warehouse_id: warehouse_id,
      location_id: location_id,
      operationtype_id: operationtype_id,
      enabled: true
    }

    case movement
    when Itemin
      inv_attrs[:itemins_id] = movement.id
    when Itemout
      inv_attrs[:itemouts_id] = movement.id
    when Itemmovement
      inv_attrs[:itemmovement_id] = movement.id
    end

    if generate_qr
      qr_code = "#{gencode}_#{format('%04d', (detail.collection_id || 0).to_i)}_#{detail.id}"
      inv_attrs[:qrcode_svg] = CreateQrService.new.svg(qr_code)
    end

    record = Inventory.create!(inv_attrs)
    StockLevel.adjust_qty!(gencode, warehouse_id, location_id, qty.to_i * delta)
    record
  end
end
