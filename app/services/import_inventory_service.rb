class ImportInventoryService
  require 'roo'

  def parse(file, metadata = {})
    spreadsheet = Roo::Excelx.new(file)
    headers = spreadsheet.row(1)

    rows = (2..spreadsheet.last_row).map do |i|
      row = Hash[[headers, spreadsheet.row(i)].transpose]
      row[:_index] = i
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

  def save(data, user = nil)
    stats = { total: data[:rows].size, created: 0, errors: [], items: [], skipped: [] }
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

      details = op_type_id == 1 ? movement.itemins_details : movement.itemouts_details
      details.each_with_index do |detail, i|
        row = data[:rows][i]
        inventory = Inventory.create!(
          itemcode: detail.itemcode,
          qtyavailable: detail.qty,
          minstock: row['Min Stock'] || row['minstock'] || row['Min'] || 0,
          maxstock: row['Max Stock'] || row['maxstock'] || row['Max'] || 0,
          warehouse_id: data[:warehouse_id],
          location_id: data[:location_id].presence,
          operationtype_id: op_type_id,
          itemins_id: (op_type_id == 1 ? movement.id : nil),
          itemouts_id: (op_type_id == 2 ? movement.id : nil),
          enabled: true
        )
        stats[:items] << { itemcode: detail.itemcode, qty: detail.qty, inventory_id: inventory.id }
        stats[:created] += 1
      end
    end

    stats
  rescue => e
    stats[:errors] << { row: 0, error: e.message }
    stats
  end
end