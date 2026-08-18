class ImportInventoryService < SpreadsheetImportBase
  def known_headers
    ['Item Code:', 'Description:', 'Qt.', 'Fabric code:', 'var. code:', 'Fabric Code', 'Fabricode', 'Quantity', 'QTA', 'qtyavailable'].freeze
  end

  def after_row(row)
    resolve_warehouse_location_collection(row)
  end

  def extra_metadata
    {
      warehouse_id: @metadata[:warehouse_id],
      location_id: @metadata[:location_id],
      operationtype_id: @metadata[:operationtype_id]
    }
  end

  def resolve_warehouse_location_collection(row)
    override_warehouse_id = @metadata[:warehouse_id].to_i if @metadata[:warehouse_id].present?
    override_location_id = @metadata[:location_id].to_i if @metadata[:location_id].present?

    if override_warehouse_id
      w = Warehouse.find(override_warehouse_id)
      row[:_warehouse_id] = w.id
      row[:_warehouse_code] = w.code
      row[:_warehouse_new] = false
    else
      dove_val = cell(row, 'dove').to_s.strip
      if dove_val.present?
        existing_w = Warehouse.find_by(code: dove_val)
        if existing_w
          row[:_warehouse_id] = existing_w.id
          row[:_warehouse_code] = existing_w.code
          row[:_warehouse_new] = false
        else
          w = find_or_create_warehouse(dove_val)
          row[:_warehouse_id] = w.id
          row[:_warehouse_code] = w.code
          row[:_warehouse_new] = true
        end
      end
    end

    if override_location_id
      loc = Location.find(override_location_id)
      row[:_location_id] = loc.id
      row[:_location_code] = loc.code
    end

    note_val = cell(row, 'Note:').to_s.strip
    if note_val.present?
      existing_c = Collection.find_by(description: note_val)
      if existing_c
        row[:_collection_id] = existing_c.id
        row[:_collection_description] = existing_c.description
        row[:_collection_new] = false
      else
        c = find_or_create_collection(note_val)
        row[:_collection_id] = c.id
        row[:_collection_description] = c.description
        row[:_collection_new] = true
      end
    end
  end

  def validate_row(row)
    itemcode = cell(row, 'Item Code:', 'itemcode', 'Item Code')
    fabricode = cell(row, 'fabricode', 'Fabric Code', 'Fabricode', 'Fabric code', 'Fabric code:')
    varcode = cell(row, 'varcode', 'Var Code', 'Var', 'var. code:')

    if itemcode.blank?
      row[:_valid] = false
      row[:_error] = "Item code mancante"
      return
    end

    existing = if fabricode.present? && varcode.present?
      Item.find_by(itemcode: itemcode, fabricode: fabricode, varcode: varcode)
    elsif varcode.present?
      Item.find_by(itemcode: itemcode, varcode: varcode) || Item.find_by(itemcode: itemcode) || Item.find_by(gencode: itemcode)
    else
      Item.find_by(itemcode: itemcode) || Item.find_by(gencode: itemcode)
    end

    if existing
      row[:_valid] = true
      row[:_error] = nil
      row[:_item_id] = existing.id
      row[:_itemcode] = existing.itemcode if existing.gencode == itemcode
    else
      row[:_valid] = false
      row[:_error] = "Articolo #{itemcode}#{" / #{fabricode}" if fabricode}#{" / #{varcode}" if varcode} non trovato"
    end
  end

  def create_missing_items(data)
    invalid_rows = data[:rows].select do |row|
      !row[:_valid] && cell(row, 'Item Code:', 'itemcode', 'Item Code').present?
    end

    missing = invalid_rows.group_by do |row|
      [
        cell(row, 'Item Code:', 'itemcode', 'Item Code').to_s.strip,
        cell(row, 'fabricode', 'Fabric Code', 'Fabricode', 'Fabric code', 'Fabric code:')&.to_s&.strip,
        cell(row, 'varcode', 'Var Code', 'Var', 'var. code:')&.to_s&.strip
      ]
    end

    created = 0
    failed = []

    Item.skip_callback(:save, :before, :regenerate_qr)
    begin
      missing.each do |(itemcode, fabricode, varcode), rows|
        collection_description = rows.filter_map { |r| cell(r, 'Note:')&.to_s&.strip }.find(&:present?)
        collection = find_or_create_collection(collection_description)

        if collection.nil?
          failed << { itemcode: itemcode, error: "Collection mancante (Note: vuoto)" }
          next
        end

        sample = rows.first
        item = Item.find_or_initialize_by(itemcode: itemcode, fabricode: fabricode, varcode: varcode)
        item.collection = collection
        item.description = cell(sample, 'Description: ', 'Description:', 'description')
        item.tg = cell(sample, 'Tg.')
        item.fabric = cell(sample, 'fabric:', 'Fabric:')
        item.colour = cell(sample, 'colour:', 'Colour:')
        item.materiale = cell(sample, 'materiale')

        if item.save
          created += 1
        else
          failed << { itemcode: itemcode, error: item.errors.full_messages.join(", ") }
        end
      end
    ensure
      Item.set_callback(:save, :before, :regenerate_qr, if: :gencode_changed?)
    end

    data[:rows].each { |row| validate_row(row) if row[:_error].to_s.end_with?("non trovato") }

    { created: created, failed: failed }
  end

  def save(data, user = nil)
    stats = { total: data[:rows].size, created: 0, errors: [], items: [], skipped: [], invalid: [] }
    op_type_id = data[:operationtype_id].to_i

    return stats unless [1, 2].include?(op_type_id)

    ActiveRecord::Base.transaction do
      movement = if op_type_id == 1
        Itemin.new(indate: Date.current, operator_id: user&.id, notes: "Importazione Excel", imported: true)
      else
        Itemout.new(indate: Date.current, operator_id: user&.id, notes: "Importazione Excel", imported: true)
      end

      data[:rows].each do |row|
        unless row[:_valid]
          itemcode = cell(row, 'Item Code:', 'itemcode', 'Item Code')
          stats[:invalid] << { itemcode: itemcode, row: row[:_index], error: row[:_error] }
          next
        end

        raw_itemcode = cell(row, 'Item Code:', 'itemcode', 'Item Code')
        qty = (cell(row, 'Qt.', 'Quantity', 'qtyavailable', 'QTA') || 0).to_i

        if qty == 0
          stats[:skipped] << { itemcode: raw_itemcode, row: row[:_index] }
          next
        end

        item = if row[:_item_id]
          Item.find_by(id: row[:_item_id])
        else
          Item.find_by(itemcode: raw_itemcode) || Item.find_by(gencode: raw_itemcode)
        end

        if item.nil?
          stats[:invalid] << { itemcode: raw_itemcode, row: row[:_index], error: "Articolo non trovato" }
          next
        end

        warehouse_id = row[:_warehouse_id] || data[:warehouse_id]

        if warehouse_id.blank?
          stats[:invalid] << { itemcode: raw_itemcode, row: row[:_index], error: "Magazzino non specificato" }
          next
        end

        warehouse_obj = Warehouse.find(warehouse_id)

        detail_attrs = {
          itemcode: row[:_itemcode] || item&.itemcode || raw_itemcode,
          item_id: item&.id,
          qty: qty,
          warehouse: warehouse_obj,
          collection_id: row[:_collection_id],
          location_id: row[:_location_id],
          operationtype_id: op_type_id
        }

        if op_type_id == 1
          movement.itemins_details.build(detail_attrs)
        else
          movement.itemouts_details.build(detail_attrs)
        end
      end

      movement.save!
      InventoryCreator.new.call(movement)

      details = op_type_id == 1 ? movement.itemins_details : movement.itemouts_details
      details.each_with_index do |detail, i|
        stats[:items] << { itemcode: detail.itemcode, qty: detail.qty, inventory_id: i }
        stats[:created] += 1
      end
    end

    stats
  rescue => e
    stats[:errors] << { row: 0, error: extract_error(e) }
    stats
  end
end
