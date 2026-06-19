class ImportInventoryService
  require 'roo'

  def parse(file, metadata = {})
    spreadsheet = Roo::Excelx.new(file)
    headers = spreadsheet.row(1)

    rows = (2..spreadsheet.last_row).map do |i|
      row = Hash[[headers, spreadsheet.row(i)].transpose]
      row[:_index] = i
      validate_row(row)
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

  def validate_row(row)
    itemcode = row['Item Code:'] || row['itemcode'] || row['Item Code']
    fabricode = row['fabricode'] || row['Fabric Code'] || row['Fabricode']
    varcode = row['varcode'] || row['Var Code'] || row['Var']

    if itemcode.blank?
      row[:_valid] = false
      row[:_error] = "Item code mancante"
      return
    end

    existing = if fabricode.present? && varcode.present?
      Item.find_by(itemcode: itemcode, fabricode: fabricode, varcode: varcode)
    else
      Item.find_by(itemcode: itemcode)
    end

    if existing
      row[:_valid] = true
      row[:_error] = nil
    else
      row[:_valid] = false
      row[:_error] = "Articolo #{itemcode}#{" / #{fabricode}" if fabricode}#{" / #{varcode}" if varcode} non trovato"
    end
  end

  def save(data, user = nil)
    stats = { total: data[:rows].size, created: 0, errors: [], items: [], skipped: [], invalid: [] }
    op_type_id = data[:operationtype_id].to_i

    return stats unless [1, 2].include?(op_type_id)

    warehouse = Warehouse.find(data[:warehouse_id])

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

        itemcode = row['Item Code:'] || row['itemcode'] || row['Item Code']
        qty = (row['Qt.'] || row['Quantity'] || row['qtyavailable'] || row['QTA'] || 0).to_i

        if qty == 0
          stats[:skipped] << { itemcode: itemcode, row: row[:_index] }
          next
        end

        detail_attrs = {
          itemcode: itemcode,
          qty: qty,
          warehouse: warehouse,
          location_id: data[:location_id].presence,
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