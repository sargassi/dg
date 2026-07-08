class ImportInventoryService
  require 'roo'

  KNOWN_HEADERS = ['Item Code:', 'Description:', 'Qt.', 'Fabric code:', 'var. code:', 'Fabric Code', 'Fabricode', 'Quantity', 'QTA', 'qtyavailable'].freeze

  def parse(file, metadata = {})
    override_warehouse_id = metadata[:warehouse_id].to_i if metadata[:warehouse_id].present?
    override_location_id = metadata[:location_id].to_i if metadata[:location_id].present?

    spreadsheet = Roo::Excelx.new(file)
    header_row = find_header_row(spreadsheet)
    headers = spreadsheet.row(header_row)

    rows = ((header_row + 1)..spreadsheet.last_row).map do |i|
      row = Hash[[headers, spreadsheet.row(i)].transpose]
      row[:_index] = i
      validate_row(row)
      resolve_warehouse_location_collection(row,
        override_warehouse_id: override_warehouse_id,
        override_location_id: override_location_id)
      row
    end

    {
      headers: headers,
      rows: rows,
      warehouse_id: metadata[:warehouse_id],
      location_id: metadata[:location_id],
      operationtype_id: metadata[:operationtype_id]
    }
  end

  def find_header_row(spreadsheet)
    (1..spreadsheet.last_row).each do |i|
      row = spreadsheet.row(i)
      next if row.nil? || row.empty?
      matches = KNOWN_HEADERS.count { |h| row.any? { |cell| cell.to_s.strip == h } }
      return i if matches >= 2
    end
    1
  end

  def resolve_warehouse_location_collection(row, override_warehouse_id: nil, override_location_id: nil)
    if override_warehouse_id
      w = Warehouse.find(override_warehouse_id)
      row[:_warehouse_id] = w.id
      row[:_warehouse_code] = w.code
      row[:_warehouse_new] = false
    else
      dove_val = row['dove'].to_s.strip
      if dove_val.present?
        existing_w = Warehouse.find_by(code: dove_val)
        if existing_w
          row[:_warehouse_id] = existing_w.id
          row[:_warehouse_code] = existing_w.code
          row[:_warehouse_new] = false
        else
          w = Warehouse.create!(code: dove_val, enabled: true)
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

    note_val = row['Note:'].to_s.strip
    if note_val.present?
      existing_c = Collection.find_by(description: note_val)
      if existing_c
        row[:_collection_id] = existing_c.id
        row[:_collection_description] = existing_c.description
        row[:_collection_new] = false
      else
        c = Collection.create!(description: note_val)
        row[:_collection_id] = c.id
        row[:_collection_description] = c.description
        row[:_collection_new] = true
      end
    end
  end

  def validate_row(row)
    itemcode = row['Item Code:'] || row['itemcode'] || row['Item Code']
    fabricode = row['fabricode'] || row['Fabric Code'] || row['Fabricode'] || row['Fabric code'] || row['Fabric code:']
    varcode = row['varcode'] || row['Var Code'] || row['Var'] || row['var. code:']

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

  def save(data, user = nil)
    stats = { total: data[:rows].size, created: 0, errors: [], items: [], skipped: [], invalid: [] }
    op_type_id = data[:operationtype_id].to_i

    return stats unless [1, 2].include?(op_type_id)

    ActiveRecord::Base.transaction do
      movement = if op_type_id == 1
        Itemin.new(indate: Date.current, operator_id: user&.id, notes: "Importazione Excel")
      else
        Itemout.new(indate: Date.current, operator_id: user&.id, notes: "Importazione Excel")
      end

      data[:rows].each do |row|
        unless row[:_valid]
          itemcode = row['Item Code:'] || row['itemcode'] || row['Item Code']
          stats[:invalid] << { itemcode: itemcode, row: row[:_index], error: row[:_error] }
          next
        end

        raw_itemcode = row['Item Code:'] || row['itemcode'] || row['Item Code']
        qty = (row['Qt.'] || row['Quantity'] || row['qtyavailable'] || row['QTA'] || 0).to_i

        if qty == 0
          stats[:skipped] << { itemcode: raw_itemcode, row: row[:_index] }
          next
        end

        item = if row[:_item_id]
          Item.find(row[:_item_id])
        else
          Item.find_by(itemcode: raw_itemcode) || Item.find_by(gencode: raw_itemcode)
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

      if op_type_id == 1
        CreateInventoriesFromItemin.new.call(movement)
      else
        CreateInventoriesFromItemout.new.call(movement)
      end

      details = op_type_id == 1 ? movement.itemins_details : movement.itemouts_details
      details.each_with_index do |detail, i|
        stats[:items] << { itemcode: detail.itemcode, qty: detail.qty, inventory_id: i }
        stats[:created] += 1
      end
    end

    stats
  rescue => e
    error_msg = if e.respond_to?(:record) && e.record
      e.record.errors.full_messages.join(", ")
    elsif e.message.include?("record_invalid")
      "Validazione fallita"
    else
      e.message
    end
    stats[:errors] << { row: 0, error: error_msg }
    stats
  end
end
